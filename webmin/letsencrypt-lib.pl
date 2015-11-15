# Functions for cert creation with Let's Encrypt

# check_letsencrypt()
# Returns undef if all dependencies are installed, or an error message
sub check_letsencrypt
{
&has_command($config{'letsencrypt_cmd'}) ||
	return &text('letsencrypt_ecmd', "<tt>$config{'letsencrypt_cmd'}</tt>");
return undef;
}

# request_letsencrypt_cert(domain, output-path, domain-webroot)
# Attempt to request a cert using a generated key with the Let's Encrypt client
# command, and write it to the given path.
sub request_letsencrypt_cert
{
my ($dom, $path, $webroot) = @_;
my $out = &backquote_command("$config{'letsencrypt_cmd'} -a webroot -d ".quotemeta($dom)." --webroot-path ".quotemeta($webroot)." </dev/null 2>&1");
if ($?) {
	return $out;
	}
# XXX copy to path
}

1;
