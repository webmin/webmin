# Functions for cert creation with Let's Encrypt
# TODO: Renewal support

# check_letsencrypt()
# Returns undef if all dependencies are installed, or an error message
sub check_letsencrypt
{
&has_command($config{'letsencrypt_cmd'}) ||
	return &text('letsencrypt_ecmd', "<tt>$config{'letsencrypt_cmd'}</tt>");
return undef;
}

# request_letsencrypt_cert(domain, domain-webroot)
# Attempt to request a cert using a generated key with the Let's Encrypt client
# command, and write it to the given path. Returns a status flag, and either
# an error message or the paths to cert, key and chain files.
sub request_letsencrypt_cert
{
my ($dom, $webroot) = @_;
my $dir = $config{'letsencrypt_cmd'};
$dir =~ s/\/[^\/]+$//;
my $out = &backquote_command("cd $dir && $config{'letsencrypt_cmd'} certonly -a webroot -d ".quotemeta($dom)." --webroot-path ".quotemeta($webroot)." --agree-dev-preview --duplicate </dev/null 2>&1");
if ($?) {
	return (0, $out);
	}
my ($full, $cert, $key, $chain);
if ($out =~ /(\/.*\.pem)/) {
	# Output contained the full path
	$full = $1;
	}
else {
	&error("Output did not contain a PEM path!");
	}
-r $full || return (0, &text('letsencrypt_efull', $full));
$full =~ s/\/[^\/]+$//;
$cert = $full."/cert.pem";
-r $cert || return (0, &text('letsencrypt_ecert', $cert));
$key = $full."/privkey.pem";
-r $key || return (0, &text('letsencrypt_ekey', $key));
$chain = $full."/chain.pem";
$chain = undef if (!-r $chain);
return (1, $cert, $key, $chain);
}

1;
