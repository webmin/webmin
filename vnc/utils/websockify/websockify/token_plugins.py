import logging
import os
import sys
import time
import re
import json

logger = logging.getLogger(__name__)

_SOURCE_SPLIT_REGEX = re.compile(
    r'(?<=^)"([^"]+)"(?=:|$)'
    r'|(?<=:)"([^"]+)"(?=:|$)'
    r'|(?<=^)([^:]*)(?=:|$)'
    r'|(?<=:)([^:]*)(?=:|$)',
)


def parse_source_args(src):
    """It works like src.split(":") but with the ability to use a colon
    if you wrap the word in quotation marks.

    a:b:c:d -> ['a', 'b', 'c', 'd'
    a:"b:c":c -> ['a', 'b:c', 'd']
    """
    matches = _SOURCE_SPLIT_REGEX.findall(src)
    return [m[0] or m[1] or m[2] or m[3] for m in matches]


class BasePlugin():
    def __init__(self, src):
        self.source = src

    def lookup(self, token):
        return None


class ReadOnlyTokenFile(BasePlugin):
    # source is a token file with lines like
    #   token: host:port
    # or a directory of such files
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._targets = None

    def _load_targets(self):
        if os.path.isdir(self.source):
            cfg_files = [os.path.join(self.source, f) for
                         f in os.listdir(self.source)]
        else:
            cfg_files = [self.source]

        self._targets = {}
        index = 1
        for f in cfg_files:
            for line in [l.strip() for l in open(f).readlines()]:
                if line and not line.startswith('#'):
                    try:
                        tok, target = re.split(r':\s', line)
                        self._targets[tok] = target.strip().rsplit(':', 1)
                    except ValueError:
                        logger.error("Syntax error in %s on line %d" % (self.source, index))
                index += 1

    def lookup(self, token):
        if self._targets is None:
            self._load_targets()

        if token in self._targets:
            return self._targets[token]
        else:
            return None


# the above one is probably more efficient, but this one is
# more backwards compatible (although in most cases
# ReadOnlyTokenFile should suffice)
class TokenFile(ReadOnlyTokenFile):
    # source is a token file with lines like
    #   token: host:port
    # or a directory of such files
    def lookup(self, token):
        self._load_targets()

        return super().lookup(token)

class TokenFileName(BasePlugin):
    # source is a directory
    # token is filename
    # contents of file is host:port
    def __init__(self, src):
        super().__init__(src)
        if not os.path.isdir(src):
            raise Exception("TokenFileName plugin requires a directory")
    
    def lookup(self, token):
        token = os.path.basename(token)
        path = os.path.join(self.source, token)
        if os.path.exists(path):
            return open(path).read().strip().split(':')
        else:
            return None


class BaseTokenAPI(BasePlugin):
    # source is a url with a '%s' in it where the token
    # should go

    # we import things on demand so that other plugins
    # in this file can be used w/o unnecessary dependencies

    def process_result(self, resp):
        host, port = resp.text.split(':')
        port = port.encode('ascii','ignore')
        return [ host, port ]

    def lookup(self, token):
        import requests

        resp = requests.get(self.source % token)

        if resp.ok:
            return self.process_result(resp)
        else:
            return None


class JSONTokenApi(BaseTokenAPI):
    # source is a url with a '%s' in it where the token
    # should go

    def process_result(self, resp):
        resp_json = resp.json()
        return (resp_json['host'], resp_json['port'])


class JWTTokenApi(BasePlugin):
    # source is a JWT-token, with hostname and port included
    # Both JWS as JWE tokens are accepted. With regards to JWE tokens, the key is re-used for both validation and decryption.

    def lookup(self, token):
        try:
            from jwcrypto import jwt, jwk
            import json

            key = jwk.JWK()

            try:
                with open(self.source, 'rb') as key_file:
                    key_data = key_file.read()
            except Exception as e:
                logger.error("Error loading key file: %s" % str(e))
                return None

            try:
                key.import_from_pem(key_data)
            except:
                try:
                    key.import_key(k=key_data.decode('utf-8'),kty='oct')
                except:
                    logger.error('Failed to correctly parse key data!')
                    return None

            try:
                token = jwt.JWT(key=key, jwt=token)
                parsed_header = json.loads(token.header)

                if 'enc' in parsed_header:
                    # Token is encrypted, so we need to decrypt by passing the claims to a new instance
                    token = jwt.JWT(key=key, jwt=token.claims)

                parsed = json.loads(token.claims)

                if 'nbf' in parsed:
                    # Not Before is present, so we need to check it
                    if time.time() < parsed['nbf']:
                        logger.warning('Token can not be used yet!')
                        return None

                if 'exp' in parsed:
                    # Expiration time is present, so we need to check it
                    if time.time() > parsed['exp']:
                        logger.warning('Token has expired!')
                        return None

                return (parsed['host'], parsed['port'])
            except Exception as e:
                logger.error("Failed to parse token: %s" % str(e))
                return None
        except ImportError:
            logger.error("package jwcrypto not found, are you sure you've installed it correctly?")
            return None


class TokenRedis(BasePlugin):
    """Token plugin based on the Redis in-memory data store.

    The token source is in the format:

        host[:port[:db[:password[:namespace]]]]

    where port, db, password and namespace are optional. If port or db are left empty
    they will take its default value, ie. 6379 and 0 respectively.

    If your redis server is using the default port (6379) then you can use:

        my-redis-host

    In case you need to authenticate with the redis server and you are using
    the default database and port you can use:

        my-redis-host:::verysecretpass

    You can also specify a namespace. In this case, the tokens
    will be stored in the format '{namespace}:{token}'

        my-redis-host::::my-app-namespace

    Or if your namespace is nested, you can wrap it in quotes:

        my-redis-host::::"first-ns:second-ns"

    In the more general case you will use:

        my-redis-host:6380:1:verysecretpass:my-app-namespace

    The TokenRedis plugin expects the format of the target in one of these two
    formats:

    - JSON

        {"host": "target-host:target-port"}

    - Plain text

        target-host:target-port

    Prepare data with:

        redis-cli set my-token '{"host": "127.0.0.1:5000"}'

    Verify with:

        redis-cli --raw get my-token

    Spawn a test "server" using netcat

        nc -l 5000 -v

    Note: This Token Plugin depends on the 'redis' module, so you have
    to install it before using this plugin:

          pip install redis
    """
    def __init__(self, src):
        try:
            import redis
        except ImportError:
            logger.error("Unable to load redis module")
            sys.exit()
        # Default values
        self._port = 6379
        self._db = 0
        self._password = None
        self._namespace = ""
        try:
            fields = parse_source_args(src)
            if len(fields) == 1:
                self._server = fields[0]
            elif len(fields) == 2:
                self._server, self._port = fields
                if not self._port:
                    self._port = 6379
            elif len(fields) == 3:
                self._server, self._port, self._db = fields
                if not self._port:
                    self._port = 6379
                if not self._db:
                    self._db = 0
            elif len(fields) == 4:
                self._server, self._port, self._db, self._password = fields
                if not self._port:
                    self._port = 6379
                if not self._db:
                    self._db = 0
                if not self._password:
                    self._password = None
            elif len(fields) == 5:
                self._server, self._port, self._db, self._password, self._namespace = fields
                if not self._port:
                    self._port = 6379
                if not self._db:
                    self._db = 0
                if not self._password:
                    self._password = None
                if not self._namespace:
                    self._namespace = ""
            else:
                raise ValueError
            self._port = int(self._port)
            self._db = int(self._db)
            if self._namespace:
                self._namespace += ":"

            logger.info("TokenRedis backend initialized (%s:%s)" %
                  (self._server, self._port))
        except ValueError:
            logger.error("The provided --token-source='%s' is not in the "
                         "expected format <host>[:<port>[:<db>[:<password>[:<namespace>]]]]" %
                         src)
            sys.exit()

    def lookup(self, token):
        try:
            import redis
        except ImportError:
            logger.error("package redis not found, are you sure you've installed them correctly?")
            sys.exit()

        logger.info("resolving token '%s'" % token)
        client = redis.Redis(host=self._server, port=self._port,
                             db=self._db, password=self._password)
        stuff = client.get(self._namespace + token)
        if stuff is None:
            return None
        else:
            responseStr = stuff.decode("utf-8").strip()
            logger.debug("response from redis : %s" % responseStr)
            if responseStr.startswith("{"):
                try:
                    combo = json.loads(responseStr)
                    host, port = combo["host"].split(":")
                except ValueError:
                    logger.error("Unable to decode JSON token: %s" %
                                 responseStr)
                    return None
                except KeyError:
                    logger.error("Unable to find 'host' key in JSON token: %s" %
                                 responseStr)
                    return None
            elif re.match(r'\S+:\S+', responseStr):
                host, port = responseStr.split(":")
            else:
                logger.error("Unable to parse token: %s" % responseStr)
                return None
            logger.debug("host: %s, port: %s" % (host, port))
            return [host, port]


class UnixDomainSocketDirectory(BasePlugin):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._dir_path = os.path.abspath(self.source)

    def lookup(self, token):
        try:
            import stat

            if not os.path.isdir(self._dir_path):
                return None

            uds_path = os.path.abspath(os.path.join(self._dir_path, token))
            if not uds_path.startswith(self._dir_path):
                return None

            if not os.path.exists(uds_path):
                return None

            if not stat.S_ISSOCK(os.stat(uds_path).st_mode):
                return None

            return [ 'unix_socket', uds_path ]
        except Exception as e:
                logger.error("Error finding unix domain socket: %s" % str(e))
                return None
