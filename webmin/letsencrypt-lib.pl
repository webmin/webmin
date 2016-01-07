# Functions for cert creation with Let's Encrypt
# TODO: Renewal support

$letsencrypt_cmd = $config{'letsencrypt_cmd'} ||
		   &has_command("letsencrypt-auto") ||
		   &has_command("letsencrypt") ||
		   "letsencrypt";

# check_letsencrypt()
# Returns undef if all dependencies are installed, or an error message
sub check_letsencrypt
{
&has_command($letsencrypt_cmd) ||
	return &text('letsencrypt_ecmd', "<tt>$letsencrypt_cmd</tt>");
return undef;
}

# request_letsencrypt_cert(domain|&domains, domain-webroot, [email])
# Attempt to request a cert using a generated key with the Let's Encrypt client
# command, and write it to the given path. Returns a status flag, and either
# an error message or the paths to cert, key and chain files.
sub request_letsencrypt_cert
{
my ($dom, $webroot, $email) = @_;
my @doms = ref($dom) ? @$dom : ($dom);
$email ||= "root\@$dom";
my $temp = &transname();
&open_tempfile(TEMP, ">$temp");
&print_tempfile(TEMP, "email = $email\n");
&print_tempfile(TEMP, "text = True\n");
&close_tempfile(TEMP);
my $dir = $letsencrypt_cmd;
$dir =~ s/\/[^\/]+$//;
my $out = &backquote_command("cd $dir && (echo A | $letsencrypt_cmd certonly -a webroot ".join(" ", map { "-d ".quotemeta($_) } @doms)." --webroot-path ".quotemeta($webroot)." --duplicate --config $temp 2>&1)");
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
