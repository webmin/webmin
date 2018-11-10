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

sub get_letsencrypt_python_cmd
{
return &has_command("python2.7") || &has_command("python27") ||
       &has_command("python2.6") || &has_command("python26") ||
       &has_command("python");
}

# check_letsencrypt()
# Returns undef if all dependencies are installed, or an error message
sub check_letsencrypt
{
if (&has_command($letsencrypt_cmd)) {
	# Use official client
	return undef;
	}
my $python = &get_letsencrypt_python_cmd();
if (!$python || !&has_command("openssl")) {
	return $text{'letsencrypt_ecmds'};
	}
my $out = &backquote_command("$python -c 'import argparse' 2>&1");
if ($?) {
	return &text('letsencrypt_epythonmod', 'argparse');
	}
my $ver = &backquote_command("$python --version 2>&1");
if ($ver !~ /Python\s+([0-9\.]+)/) {
	return &text('letsencrypt_epythonver',
		     "<tt>".&html_escape($out)."</tt>");
	}
$ver = $1;
if ($ver < 2.5) {
	return &text('letsencrypt_epythonver2', '2.5', $ver);
	}
return undef;
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
			   "validated when the native Let's Encrypt client ".
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

if (($letsencrypt_cmd && -d "/etc/letsencrypt/accounts") || $wildcard) {
	# Use the native Let's Encrypt client if possible
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
			" --manual-public-ip-logging-ok".
			" --config $temp".
			" --rsa-key-size $size".
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
			" --manual-public-ip-logging-ok".
			" --config $temp".
			" --rsa-key-size $size".
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
else {
	# Fall back to local Python client
	$size ||= 4096;

	# But first check if the native Let's Encrypt client was used previously
	# for this system - if so, it must be used in future due to the account
	# key.
	if (-d "/etc/letsencrypt/accounts") {
		&cleanup_wellknown($wellknown_new, $challenge_new);
		return (0, &text('letsencrypt_enative', '/etc/letsencrypt'));
		}

	# Generate the account key if missing
	if (!-r $account_key) {
		my $out = &backquote_logged(
			"openssl genrsa 4096 2>&1 >$account_key");
		if ($?) {
			&cleanup_wellknown($wellknown_new, $challenge_new);
			return (0, &text('letsencrypt_eaccountkey',
					 &html_escape($out)));
			}
		}

	# Generate a key for the domain
	my $key = &transname();
	my $out = &backquote_logged("openssl genrsa $size 2>&1 >$key");
	if ($?) {
		&cleanup_wellknown($wellknown_new, $challenge_new);
		return (0, &text('letsencrypt_ekeygen', &html_escape($out)));
		}

	# Generate a CSR
	my $csr = &transname();
	my ($ok, $csr) = &generate_ssl_csr($key, undef, undef, undef,
					   undef, undef, \@doms, undef);
	if (!$ok) {
		&cleanup_wellknown($wellknown_new, $challenge_new);
		return &text('letsencrypt_ecsr', $csr);
		}
	&copy_source_dest($csr, "/tmp/lets.csr", 1);

	# Find a reasonable python version
	my $python = &get_letsencrypt_python_cmd();

	# Request the cert and key
	my $cert = &transname();
	&clean_environment();
	my $out = &backquote_logged(
		"$python $module_root_directory/acme_tiny.py ".
		"--account-key ".quotemeta($account_key)." ".
		"--csr ".quotemeta($csr)." ".
		($mode eq "web" ? "--acme-dir ".quotemeta($challenge)." "
				: "--dns-hook $dns_hook ".
				  "--cleanup-hook $cleanup_hook ").
		($staging ? "--ca https://acme-staging.api.letsencrypt.org "
			  : "").
		"--quiet ".
		"2>&1 >".quotemeta($cert));
	&reset_environment();
	if ($?) {
		my @lines = split(/\r?\n/, $out);
		my $trace;
		for(my $i=1; $i<@lines; $i++) {
			if ($lines[$i] =~ /^Traceback\s+/) {
				$trace = $i;
				last;
				}
			}
		if ($trace) {
			@lines = @lines[0 .. $trace-1];
			$out = join("\n", @lines);
			}
		&cleanup_wellknown($wellknown_new, $challenge_new);
		return (0, &text('letsencrypt_etiny',
				 "<pre>".&html_escape($out))."</pre>");
		}
	-r $cert && -s $cert || return (0, &text('letsencrypt_ecert', $cert));

	# Download the latest chained cert files
	my $chain = &transname();
	foreach my $url (@$letsencrypt_chain_urls) {
		my $cout;
		my ($host, $port, $page, $ssl) = &parse_http_url($url);
		my $err;
		&http_download($host, $port, $page, \$cout, \$err, undef, $ssl);
		if ($err) {
			&cleanup_wellknown($wellknown_new, $challenge_new);
			return (0, &text('letsencrypt_echain', $err));
			}
		if ($cout !~ /\S/ && !-r $chain) {
			&cleanup_wellknown($wellknown_new, $challenge_new);
			return (0, &text('letsencrypt_echain2', $url));
			}
		my $fh = "CHAIN";
		&open_tempfile($fh, ">>$chain");
		&print_tempfile($fh, $cout);
		&close_tempfile($fh);
		}

	# Copy the per-domain files
	my $certfinal = "$module_config_directory/$doms[0].cert";
	my $keyfinal = "$module_config_directory/$doms[0].key";
	my $chainfinal = "$module_config_directory/$doms[0].chain";
	&copy_source_dest($cert, $certfinal, 1);
	&copy_source_dest($key, $keyfinal, 1);
	&copy_source_dest($chain, $chainfinal, 1);
	&set_ownership_permissions(undef, undef, 0600, $certfinal);
	&set_ownership_permissions(undef, undef, 0600, $keyfinal);
	&set_ownership_permissions(undef, undef, 0600, $chainfinal);
	&unlink_file($cert);
	&unlink_file($key);
	&unlink_file($chain);

	&cleanup_wellknown($wellknown_new, $challenge_new);
	return (1, $certfinal, $keyfinal, $chainfinal);
	}
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
