# Functions for cert creation with Let's Encrypt

if ($config{'letsencrypt_cmd'}) {
	$letsencrypt_cmd = &has_command($config{'letsencrypt_cmd'});
	}
else {
	$letsencrypt_cmd = &has_command("letsencrypt-auto") ||
			   &has_command("letsencrypt") ||
			   &has_command("certbot-auto") ||
			   &has_command("certbot");
	}

$account_key = "$module_config_directory/letsencrypt.pem";

$letsencrypt_chain_urls = [
	"https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem",
	];

# check_letsencrypt()
# Returns undef if all dependencies are installed, or an error message
sub check_letsencrypt
{
if (&has_command($letsencrypt_cmd)) {
	# Use official client
	return undef;
	}
return $text{'letsencrypt_ecmds2'};
}

# get_letsencrypt_install_message(return-link, return-title)
# Returns a link or form to install Let's Encrypt
sub get_letsencrypt_install_message
{
my ($rlink, $rmsg) = @_;
&foreign_require("software");
return &software::missing_install_link(
	"certbot", $text{'letsencrypt_certbot'}, $rlink, $rmsg);
}

# request_letsencrypt_cert(domain|&domains, webroot, [email], [keysize],
# 			   [request-mode], [use-staging])
# Attempt to request a cert using a generated key with the Let's Encrypt client
# command, and write it to the given path. Returns a status flag, and either
# an error message or the paths to cert, key and chain files.
sub request_letsencrypt_cert
{
my ($dom, $webroot, $email, $size, $mode, $staging) = @_;
my @doms = ref($dom) ? @$dom : ($dom);
$email ||= "root\@$doms[0]";
$mode ||= "web";
my ($challenge, $wellknown, $challenge_new, $wellknown_new, $wildcard);

# Wildcard mode?
foreach my $d (@doms) {
	if ($d =~ /^\*/) {
		$wildcard = $d;
		}
	}

if ($mode eq "web") {
	# Create a challenges directory under the web root
	if ($wildcard) {
		return (0, "Wildcard hostname $wildcard can only be ".
			   "validated in DNS mode");
		}
	$wellknown = "$webroot/.well-known";
	$challenge = "$wellknown/acme-challenge";
	$wellknown_new = !-d $wellknown ? $wellknown : undef;
	$challenge_new = !-d $challenge ? $challenge : undef;
	my @st = stat($webroot);
	my $user = getpwuid($st[4]);
	if (!-d $challenge) {
		my $cmd = "mkdir -p -m 755 ".quotemeta($challenge);
		if ($user && $user ne "root") {
			$cmd = &command_as_user($user, 0, $cmd);
			}
		my $out = &backquote_logged("$cmd 2>&1");
		if ($?) {
			return (0, "mkdir failed : $out");
			}
		}

	# Create a .htaccess file to ensure the directory is accessible 
	if (&foreign_installed("apache")) {
		&foreign_require("apache");
		my $htaccess = "$challenge/.htaccess";
		if (!-r $htaccess && $apache::httpd_modules{'core'} >= 2.2) {
			&open_tempfile(HT, ">$htaccess");
			&print_tempfile(HT, "AuthType None\n");
			&print_tempfile(HT, "Require all granted\n");
			&print_tempfile(HT, "Satisfy any\n");
			&close_tempfile(HT);
			&set_ownership_permissions(
				$user, undef, 0755, $htaccess);
			}
		}
	}
elsif ($mode eq "dns") {
	# Make sure all the DNS zones exist
	if ($wildcard && !$letsencrypt_cmd) {
		return (0, "Wildcard hostname $wildcard can only be ".
			   "validated when the certbot Let's Encrypt client ".
			   "is installed");
		}
	&foreign_require("bind8");
	foreach my $d (@doms) {
		my $z = &get_bind_zone_for_domain($d);
		$z || return (0, "Neither DNS zone $d or any of its ".
				 "sub-domains exist on this system");
		}
	}
else {
	return (0, "Unknown mode $mode");
	}

# Create DNS hook wrapper scripts
my $dns_hook = "$module_config_directory/letsencrypt-dns.pl";
my $cleanup_hook = "$module_config_directory/letsencrypt-cleanup.pl";
if ($mode eq "dns") {
	&foreign_require("cron");
	&cron::create_wrapper($dns_hook, $module_name,
			      "letsencrypt-dns.pl");
	&cron::create_wrapper($cleanup_hook, $module_name,
			      "letsencrypt-cleanup.pl");
	}

# Call the native Let's Encrypt client
my $temp = &transname();
&open_tempfile(TEMP, ">$temp");
&print_tempfile(TEMP, "email = $email\n");
&print_tempfile(TEMP, "text = True\n");
&close_tempfile(TEMP);
my $dir = $letsencrypt_cmd;
$dir =~ s/\/[^\/]+$//;
$size ||= 2048;
my $out;
if ($mode eq "web") {
	# Webserver based validation
	&clean_environment();
	$out = &backquote_command(
		"cd $dir && (echo A | $letsencrypt_cmd certonly".
		" -a webroot ".
		join("", map { " -d ".quotemeta($_) } @doms).
		" --webroot-path ".quotemeta($webroot).
		" --duplicate".
		" --force-renewal".
		" --manual-public-ip-logging-ok".
		" --config $temp".
		" --rsa-key-size $size".
		" --cert-name ".quotemeta($doms[0]).
		($staging ? " --test-cert" : "").
		" 2>&1)");
	&reset_environment();
	}
elsif ($mode eq "dns") {
	# DNS based validation, via hook script
	&clean_environment();
	$out = &backquote_command(
		"cd $dir && (echo A | $letsencrypt_cmd certonly".
		" --manual".
		join("", map { " -d ".quotemeta($_) } @doms).
		" --preferred-challenges=dns".
		" --manual-auth-hook $dns_hook".
		" --manual-cleanup-hook $cleanup_hook".
		" --duplicate".
		" --force-renewal".
		" --manual-public-ip-logging-ok".
		" --config $temp".
		" --rsa-key-size $size".
		" --cert-name ".quotemeta($doms[0]).
		($staging ? " --test-cert" : "").
		" 2>&1)");
	&reset_environment();
	}
else {
	&cleanup_wellknown($wellknown_new, $challenge_new);
	return (0, "Bad mode $mode");
	}
if ($?) {
	&cleanup_wellknown($wellknown_new, $challenge_new);
	return (0, "<pre>".&html_escape($out || "No output from $letsencrypt_cmd")."</pre>");
	}
my ($full, $cert, $key, $chain);
if ($out =~ /(\/etc\/letsencrypt\/(?:live|archive)\/[a-zA-Z0-9\.\_\-\/\r\n ]*\.pem)/) {
	# Output contained the full path
	$full = $1;
	$full =~ s/\s//g;
	}
else {
	# Try searching common paths
	my @fulls = glob("/etc/letsencrypt/live/$doms[0]-*/cert.pem");
	if (@fulls) {
		my %stats = map { $_, [ stat($_) ] } @fulls;
		@fulls = sort { $stats{$a}->[9] <=> $stats{$b}->[9] }
			      @fulls;
		$full = pop(@fulls);
		}
	else {
		&cleanup_wellknown($wellknown_new, $challenge_new);
		&error("Output did not contain a PEM path!");
		}
	}
-r $full && -s $full || return (0, &text('letsencrypt_efull', $full));
$full =~ s/\/[^\/]+$//;
$cert = $full."/cert.pem";
-r $cert && -s $cert || return (0, &text('letsencrypt_ecert', $cert));
$key = $full."/privkey.pem";
-r $key && -s $key || return (0, &text('letsencrypt_ekey', $key));
$chain = $full."/chain.pem";
$chain = undef if (!-r $chain);
&set_ownership_permissions(undef, undef, 0600, $cert);
&set_ownership_permissions(undef, undef, 0600, $key);
&set_ownership_permissions(undef, undef, 0600, $chain);
&cleanup_wellknown($wellknown_new, $challenge_new);
return (1, $cert, $key, $chain);
}

# cleanup_wellknown(wellknown, challenge)
# Delete directories that were created as part of this process
sub cleanup_wellknown
{
my ($wellknown_new, $challenge_new) = @_;
&unlink_file($challenge_new) if ($challenge_new);
&unlink_file($wellknown_new) if ($wellknown_new);
}

# get_bind_zone_for_domain(domain)
# Given a hostname like www.foo.com, return the local BIND zone that contains
# it like foo.com
sub get_bind_zone_for_domain
{
my ($d) = @_;
&foreign_require("bind8");
my $bd = $d;
while ($bd =~ /\./) {
	my $z = &bind8::get_zone_name($bd, "any");
	if ($z) {
		return ($z, $bd);
		}
	$bd =~ s/^[^\.]+\.//;
	}
return ( );
}

1;
