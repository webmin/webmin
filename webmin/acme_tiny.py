#!/usr/bin/env python
import argparse, subprocess, json, os, sys, base64, binascii, time, hashlib, re, copy, textwrap, logging
try:
    from urllib.request import urlopen # Python 3
except ImportError:
    from urllib2 import urlopen # Python 2

#DEFAULT_CA = "https://acme-staging.api.letsencrypt.org"
DEFAULT_CA = "https://acme-v01.api.letsencrypt.org"

LOGGER = logging.getLogger(__name__)
LOGGER.addHandler(logging.StreamHandler())
LOGGER.setLevel(logging.INFO)

# Does sha-256 hashing of a key string for inclusion in a DNS record
def dns_digest(key):
    proc = subprocess.Popen(["openssl", "dgst", "-sha256", "-binary"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    out, err = proc.communicate(key)
    if proc.returncode != 0:
        raise IOError("OpenSSL Error: {0}".format(err))
    rv = base64.b64encode(out).replace("+", "-").replace("/", "_").rstrip("=")
    return rv

def extract_detail(result):
    rv = json.loads(result.decode('utf8'))
    if 'detail' in rv:
        return rv['detail']
    return result

def get_crt(account_key, csr, acme_dir, dns_hook, cleanup_hook, log=LOGGER, CA=DEFAULT_CA):
    # helper function base64 encode for jose spec
    def _b64(b):
        return base64.urlsafe_b64encode(b).decode('utf8').replace("=", "")

    # parse account key to get public key
    log.info("Parsing account key...")
    proc = subprocess.Popen(["openssl", "rsa", "-in", account_key, "-noout", "-text"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode != 0:
	log.error("OpenSSL Error: {0}".format(err))
        raise IOError("OpenSSL Error: {0}".format(err))
    pub_hex, pub_exp = re.search(
        r"modulus:\n\s+00:([a-f0-9\:\s]+?)\npublicExponent: ([0-9]+)",
        out.decode('utf8'), re.MULTILINE|re.DOTALL).groups()
    pub_exp = "{0:x}".format(int(pub_exp))
    pub_exp = "0{0}".format(pub_exp) if len(pub_exp) % 2 else pub_exp
    header = {
        "alg": "RS256",
        "jwk": {
            "e": _b64(binascii.unhexlify(pub_exp.encode("utf-8"))),
            "kty": "RSA",
            "n": _b64(binascii.unhexlify(re.sub(r"(\s|:)", "", pub_hex).encode("utf-8"))),
        },
    }
    accountkey_json = json.dumps(header['jwk'], sort_keys=True, separators=(',', ':'))
    thumbprint = _b64(hashlib.sha256(accountkey_json.encode('utf8')).digest())

    # helper function make signed requests
    def _send_signed_request(url, payload):
        payload64 = _b64(json.dumps(payload).encode('utf8'))
        protected = copy.deepcopy(header)
        protected["nonce"] = urlopen(CA + "/directory").headers['Replay-Nonce']
        protected64 = _b64(json.dumps(protected).encode('utf8'))
        proc = subprocess.Popen(["openssl", "dgst", "-sha256", "-sign", account_key],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate("{0}.{1}".format(protected64, payload64).encode('utf8'))
        if proc.returncode != 0:
            raise IOError("OpenSSL Error: {0}".format(err))
        data = json.dumps({
            "header": header, "protected": protected64,
            "payload": payload64, "signature": _b64(out),
        })
        try:
            resp = urlopen(url, data.encode('utf8'))
            return resp.getcode(), resp.read()
        except IOError as e:
            return getattr(e, "code", None), getattr(e, "read", e.__str__)()

    # find domains
    log.info("Parsing CSR...")
    proc = subprocess.Popen(["openssl", "req", "-in", csr, "-noout", "-text"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode != 0:
        log.error("Error loading {0}: {1}".format(csr, err))
        raise IOError("Error loading {0}: {1}".format(csr, err))
    domains = set([])
    common_name = re.search(r"Subject:.*? CN\s?=\s?([^\s,;/]+)", out.decode('utf8'))
    if common_name is not None:
        domains.add(common_name.group(1))
    alt_names = re.search(r"Subject:.*subjectAltName=([^\s,;/]+)", out.decode('utf8'))
    if alt_names is not None:
	for alt in alt_names.group(1).split(","):
	    dnsnum, altdom = alt.split("=")
	    domains.add(altdom)
    subject_alt_names = re.search(r"X509v3 Subject Alternative Name: \n +([^\n]+)\n", out.decode('utf8'), re.MULTILINE|re.DOTALL)
    if subject_alt_names is not None:
        for san in subject_alt_names.group(1).split(", "):
            if san.startswith("DNS:"):
                domains.add(san[4:])

    # get the certificate domains and expiration
    log.info("Registering account...")
    code, result = _send_signed_request(CA + "/acme/new-reg", {
        "resource": "new-reg",
        "agreement": "https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf",
    })
    if code == 201:
        log.info("Registered!")
    elif code == 409:
        log.info("Already registered!")
    else:
	log.error("Error registering: {0}".format(extract_detail(result)))
        raise ValueError("Error registering: {0} {1}".format(code, result))

    # verify each domain
    for domain in domains:
        log.info("Verifying {0}...".format(domain))

        # get new challenge
	if dns_hook:
	    ctype = "dns-01"
	else:
	    ctype = "http-01"
        code, result = _send_signed_request(CA + "/acme/new-authz", {
            "resource": "new-authz",
            "identifier": {"type": "dns", "value": domain},
        })
        if code != 201:
            log.error("Error requesting challenges: {0}".format(extract_detail(result)))
            raise ValueError("Error requesting challenges: {0} {1}".format(code, result))

	# create the challenge string
        challenge = [c for c in json.loads(result.decode('utf8'))['challenges'] if c['type'] == ctype][0]
        token = re.sub(r"[^A-Za-z0-9_\-]", "_", challenge['token'])
        keyauthorization = "{0}.{1}".format(token, thumbprint)

	if dns_hook:
	    # call out to the DNS record creation hook
	    os.environ['CERTBOT_DOMAIN'] = domain
	    os.environ['CERTBOT_VALIDATION'] = dns_digest(keyauthorization)
	    os.system(dns_hook)
	else:
            # make the challenge file
            wellknown_path = os.path.join(acme_dir, token)
            with open(wellknown_path, "w") as wellknown_file:
                wellknown_file.write(keyauthorization)
	        os.chmod(wellknown_path, 0777)

            # check that the file is in place
            wellknown_url = "http://{0}/.well-known/acme-challenge/{1}".format(domain, token)
            try:
                resp = urlopen(wellknown_url)
                resp_data = resp.read().decode('utf8').strip()
                assert resp_data == keyauthorization
            except (IOError, AssertionError):
    	        log.warning("Wrote file to {0}, but couldn't download {1}".
			    format(wellknown_path, wellknown_url))

        # notify challenge are met
        code, result = _send_signed_request(challenge['uri'], {
            "resource": "challenge",
            "keyAuthorization": keyauthorization,
        })
        if code != 202:
            log.error("Error triggering challenge: {0}".format(extract_detail(result)))
            raise ValueError("Error triggering challenge: {0} {1}".format(code, result))

        # wait for challenge to be verified (for up to 240 seconds)
	tries = 0
        while True:
            try:
                resp = urlopen(challenge['uri'])
                challenge_status = json.loads(resp.read().decode('utf8'))
            except IOError as e:
		log.error("Error checking challenge: {0}".format(e.code))
                raise ValueError("Error checking challenge: {0} {1}".format(
                    e.code, json.loads(e.read().decode('utf8'))))
            if challenge_status['status'] == "pending":
		tries = tries + 1
		if tries > 120:
		    log.error("Gave up waiting for validation")
		    raise ValueError("Gave up waiting for validation")
                time.sleep(2)
            elif challenge_status['status'] == "valid":
                log.info("{0} verified!".format(domain))
		if dns_hook:
		    # Cleanup DNS records
		    if cleanup_hook:
		        os.system(cleanup_hook)
		else:
                    os.remove(wellknown_path)
                break
            else:
		log.error("{0} challenge did not pass: {1}".format(domain, challenge_status['error']['detail']))
                raise ValueError("{0} challenge did not pass: {1}".format(
                    domain, challenge_status))

    # get the new certificate
    log.info("Signing certificate...")
    proc = subprocess.Popen(["openssl", "req", "-in", csr, "-outform", "DER"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    csr_der, err = proc.communicate()
    code, result = _send_signed_request(CA + "/acme/new-cert", {
        "resource": "new-cert",
        "csr": _b64(csr_der),
    })
    if code != 201:
	log.error("Error signing certificate: {0} {1}".format(code, extract_detail(result)))
        raise ValueError("Error signing certificate: {0} {1}".format(code, result))

    # return signed certificate!
    log.info("Certificate signed!")
    return """-----BEGIN CERTIFICATE-----\n{0}\n-----END CERTIFICATE-----\n""".format(
        "\n".join(textwrap.wrap(base64.b64encode(result).decode('utf8'), 64)))

def main(argv):
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent("""\
            This script automates the process of getting a signed TLS certificate from
            Let's Encrypt using the ACME protocol. It will need to be run on your server
            and have access to your private account key, so PLEASE READ THROUGH IT! It's
            only ~200 lines, so it won't take long.

            ===Example Usage===
            python acme_tiny.py --account-key ./account.key --csr ./domain.csr --acme-dir /usr/share/nginx/html/.well-known/acme-challenge/ > signed.crt
            ===================

            ===Example Crontab Renewal (once per month)===
            0 0 1 * * python /path/to/acme_tiny.py --account-key /path/to/account.key --csr /path/to/domain.csr --acme-dir /usr/share/nginx/html/.well-known/acme-challenge/ > /path/to/signed.crt 2>> /var/log/acme_tiny.log
            ==============================================
            """)
    )
    parser.add_argument("--account-key", required=True, help="path to your Let's Encrypt account private key")
    parser.add_argument("--csr", required=True, help="path to your certificate signing request")
    parser.add_argument("--acme-dir", required=False, help="path to the .well-known/acme-challenge/ directory")
    parser.add_argument("--dns-hook", required=False, help="script to perform DNS validation setup")
    parser.add_argument("--cleanup-hook", required=False, help="script to perform DNS validation cleanup")
    parser.add_argument("--quiet", action="store_const", const=logging.ERROR, help="suppress output except for errors")
    parser.add_argument("--ca", default=DEFAULT_CA, help="certificate authority, default is Let's Encrypt")

    args = parser.parse_args(argv)
    LOGGER.setLevel(args.quiet or LOGGER.level)
    signed_crt = get_crt(args.account_key, args.csr, args.acme_dir, args.dns_hook, args.cleanup_hook, log=LOGGER, CA=args.ca)
    sys.stdout.write(signed_crt)

if __name__ == "__main__": # pragma: no cover
    main(sys.argv[1:])
