## Reporting Security Issues

Please send all reports of security issues found in Webmin to security@webmin.com
via email, ideally PGP encrypted with the key from https://www.webmin.com/jcameron-key.asc .

Potential security issues, in descending order of impact, include :

* Remotely exploitable attacks that allow `root` access to Webmin without
  any credentials.

* Privilege escalation vulnerabilities that allow non-`root` users of Webmin
  to run commands or access files as `root`.

* XSS attacks that target users already logged into Webmin when they visit
  another website.

Things that are not actually security issues include :

* XSS attacks that are blocked by Webmin's referrer checks, which are enabled
  by default.

* Attacks that require modifications to Webmin's code or configuration, which
  can only be done by someone who already has `root` permissions.
