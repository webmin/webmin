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
	"https://letsencrypt.org/certs/lets-encrypt-r3-cross-signed.pem",
	"https://letsencrypt.org/certs/lets-encrypt-r3.pem",
	"https://letsencrypt.org/certs/lets-encrypt-e1.pem",
	];

# check_letsencrypt()
# Returns undef if all dependencies are installed, or an error message
sub check_letsencrypt
{
if (&has_command($letsencrypt_cmd)) {
	# Use official client
	return undef;
	}
my $python = &get_python_cmd();
if (!$python || !&has_command("openssl")) {
        return $text{'letsencrypt_ecmds'};
        }
my $out = &backquote_command("$python -c 'import argparse' 2>&1");
if ($?) {
        return &text('letsencrypt_epythonmod', '<tt>argparse</tt>');
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
# 			   [request-mode], [use-staging], [account-email],
# 			   [key-type], [reuse-key],
# 			   [server-url, server-key, server-hmac],
# 			   [allow-subset])
# Attempt to request a cert using a generated key with the Let's Encrypt client
# command, and write it to the given path. Returns a status flag, and either
# an error message or the paths to cert, key and chain files.
sub request_letsencrypt_cert
{
my ($dom, $webroot, $email, $size, $mode, $staging, $account_email,
    $key_type, $reuse_key, $server, $server_key, $server_hmac, $subset) = @_;
my @doms = ref($dom) ? @$dom : ($dom);
$email ||= "root\@$doms[0]";
$mode ||= "web";
@doms = &unique(@doms);
$reuse_key = $config{'letsencrypt_reuse'} if (!defined($reuse_key));
my ($challenge, $wellknown, $challenge_new, $wellknown_new, $wildcard);

# Wildcard mode?
foreach my $d (@doms) {
	if ($d =~ /^\*/) {
		$wildcard = $d;
		}
	}

if ($server && !$letsencrypt_cmd) {
	return (0, "A non-standard server can only be used when the native ".
		   "Let's Encrypt client is installed");
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
		my $cmd = "mkdir -p -m 755 ".quotemeta($challenge).
			  " && chmod 755 ".quotemeta($wellknown);
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
		my $d = &get_virtualmin_for_domain($d);
		$z || $d || return (0, "Neither DNS zone $d or any of its ".
				       "sub-domains exist on this system");
		}
	}
elsif ($mode eq "certbot") {
	# Nothing to check here, since verification is done by the standalone
	# certbot server
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

# Run the before command
if ($config{'letsencrypt_before'}) {
	my $out = &backquote_logged("$config{'letsencrypt_before'} 2>&1 </dev/null");
	if ($?) {
		return (0, "Pre-request command failed : $out");
		}
	}

my @rv;
if ($letsencrypt_cmd) {
	# Call the native Let's Encrypt client
	my $temp = &transname();
	&open_tempfile(TEMP, ">$temp");
	&print_tempfile(TEMP, "email = $email\n");
	&print_tempfile(TEMP, "text = True\n");
	&close_tempfile(TEMP);
	my $dir = $letsencrypt_cmd;
	my $cmd_ver = &get_certbot_major_version($letsencrypt_cmd);
	my $old_flags = "";
	my $new_flags = "";
	my $reuse_flags = "";
	my $server_flags = "";
	my $subset_flags = "";
	$key_type ||= $config{'letsencrypt_algo'} || 'rsa';
	if (&compare_version_numbers($cmd_ver, '<', 1.11)) {
		$old_flags = " --manual-public-ip-logging-ok";
		}
	if (&compare_version_numbers($cmd_ver, '>=', 2.0)) {
		$new_flags = " --key-type ".quotemeta($key_type);
		}
	if ($reuse_key) {
		$reuse_flags = " --reuse-key";
		}
	else {
		$reuse_flags = " --no-reuse-key";
		}
	if ($subset) {
		$subset_flags = " --allow-subset-of-names";
		}
	if (($reuse_key && $reuse_key == -1) ||
	    &compare_version_numbers($cmd_ver, '<', '1.13.0')) {
		$reuse_flags = ""
		}
	if ($server) {
		$server_flags = " --server ".quotemeta($server);
		if ($server_key) {
			$server_flags .= " --eab-kid ".quotemeta($server_key);
			}
		if ($server_hmac) {
			$server_flags .= " --eab-hmac-key ".
					 quotemeta($server_hmac);
			}
		}
	$dir =~ s/\/[^\/]+$//;
	$size ||= 2048;
	my $out;
	my $common_flags = " --duplicate".
			   " --force-renewal".
			   " --non-interactive".
			   " --agree-tos".
			   " --config ".quotemeta($temp)."".
			   " --rsa-key-size ".quotemeta($size).
			   " --cert-name ".quotemeta($doms[0]).
			   " --no-autorenew".
			   ($staging ? " --test-cert" : "");
	if ($mode eq "web") {
		# Webserver based validation
		&clean_environment();
		$out = &backquote_logged(
			"cd $dir && (echo A | $letsencrypt_cmd certonly".
			" -a webroot ".
			join("", map { " -d ".quotemeta($_) } @doms).
			" --webroot-path ".quotemeta($webroot).
			$common_flags.
			$reuse_flags.
			$old_flags.
			$server_flags.
			$new_flags.
			$subset_flags.
			" 2>&1)");
		&reset_environment();
		}
	elsif ($mode eq "dns") {
		# DNS based validation, via hook script
		&clean_environment();
		$out = &backquote_logged(
			"cd $dir && (echo A | $letsencrypt_cmd certonly".
			" --manual".
			join("", map { " -d ".quotemeta($_) } @doms).
			" --preferred-challenges=dns".
			" --manual-auth-hook $dns_hook".
			" --manual-cleanup-hook $cleanup_hook".
			$common_flags.
			$reuse_flags.
			$old_flags.
			$server_flags.
			$new_flags.
			$subset_flags.
			" 2>&1)");
		&reset_environment();
		}
	elsif ($mode eq "certbot") {
		# Use certbot's own webserver
		&clean_environment();
		$out = &backquote_logged(
			"cd $dir && (echo A | $letsencrypt_cmd certonly".
			" --standalone".
			join("", map { " -d ".quotemeta($_) } @doms).
			$common_flags.
			$reuse_flags.
			$old_flags.
			$server_flags.
			$new_flags.
			$subset_flags.
			" 2>&1)");
		&reset_environment();
		}
	else {
		@rv = (0, "Bad mode $mode");
		goto FAILED;
		}
	if ($?) {
		@rv = (0, "<pre>".&html_escape($out || "No output from $letsencrypt_cmd")."</pre>");
		goto FAILED;
		}
	my ($full, $cert, $key, $chain);
	if ($out =~ /((?:\/usr\/local)?\/etc\/letsencrypt\/(?:live|archive)\/[a-zA-Z0-9\.\_\-\/\r\n\* ]*\.pem)/) {
		# Output contained the full path
		$full = $1;
		$full =~ s/\s//g;
		}
	else {
		# Try searching common paths
		my @fulls = (glob("/etc/letsencrypt/live/$doms[0]-*/cert.pem"),
			     glob("/usr/local/etc/letsencrypt/live/$doms[0]-*/cert.pem"));
		if (@fulls) {
			my %stats = map { $_, [ stat($_) ] } @fulls;
			@fulls = sort { $stats{$a}->[9] <=> $stats{$b}->[9] }
				      @fulls;
			$full = pop(@fulls);
			}
		else {
			@rv = (0, "Output did not contain a PEM path!");
			goto FAILED;
			}
		}
	if (!-r $full || !-s $full) {
		@rv = (0, &text('letsencrypt_efull', $full));
		goto FAILED;
		}
	$full =~ s/\/[^\/]+$//;
	$cert = $full."/cert.pem";
	if (!-r $cert || !-s $cert) {
		@rv = (0, &text('letsencrypt_ecert', $cert));
		goto FAILED;
		}
	$key = $full."/privkey.pem";
	if (!-r $key || !-s $key) {
		@rv = (0, &text('letsencrypt_ekey', $key));
		goto FAILED;
		}
	$chain = $full."/chain.pem";
	$chain = undef if (!-r $chain);
	&set_ownership_permissions(undef, undef, 0600, $cert);
	&set_ownership_permissions(undef, undef, 0600, $key);
	&set_ownership_permissions(undef, undef, 0600, $chain);

	if ($account_email) {
		# Attempt to update the contact email on file with let's encrypt
		&system_logged(
		    "$letsencrypt_cmd register --update-registration".
		    " --email ".quotemeta($account_email).
		    " >/dev/null 2>&1 </dev/null");
		}

	@rv = (1, $cert, $key, $chain);
	}
elsif ($mode eq "dns" || $mode eq "certbot") {
	# Python client doesn't support DNS or Certbot
	@rv = (0, $text{'letsencrypt_eacme'.$mode});
	}
else {
	# Fall back to local Python client
	$size ||= 4096;

	# Generate the account key if missing
	if (!-r $account_key) {
		my $out = &backquote_logged(
			"openssl genrsa 4096 2>&1 >$account_key");
		if ($?) {
			@rv = (0, &text('letsencrypt_eaccountkey',
					&html_escape($out)));
			goto FAILED;
			}
		}

	# Generate a key for the domain
	my $key = &transname();
	my $out = &backquote_logged("openssl genrsa $size 2>&1 >".quotemeta($key)."");
	if ($?) {
		@rv = (0, &text('letsencrypt_ekeygen', &html_escape($out)));
		goto FAILED;
		}

	# Generate a CSR
	my $csr = &transname();
	my ($ok, $csr) = &generate_ssl_csr($key, undef, undef, undef,
					   undef, undef, \@doms, undef);
	if (!$ok) {
		@rv = &text('letsencrypt_ecsr', $csr);
		goto FAILED;
		}
	&copy_source_dest($csr, "/tmp/lets.csr", 1);

	# Find a reasonable python version
	my $python = &get_python_cmd();

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
		($staging ? "--ca https://acme-staging-v02.api.letsencrypt.org "
			  : "--disable-check ").
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
		@rv = (0, &text('letsencrypt_etiny',
				"<pre>".&html_escape($out))."</pre>");
		goto FAILED;
		}
	if (!-r $cert || !-s $cert) {
		@rv = (0, &text('letsencrypt_ecert', $cert));
		goto FAILED;
		}

	# Check if the returned cert contains a CA cert as well
	my $chain = &transname();
	my @certs = &cert_file_split($cert);
	if (@certs > 1) {
		# Yes .. keep the first as the cert, and use the others as
		# the chain
		my $orig = shift(@certs);
		my $fh = "CHAIN";
		&open_tempfile($fh, ">$chain");
		foreach my $c (@certs) {
			&print_tempfile($fh, $c);
			}
		&close_tempfile($fh);
		my $fh2 = "CERT";
		&open_tempfile($fh2, ">$cert");
		&print_tempfile($fh2, $orig);
		&close_tempfile($fh2);
		}
	else {
		# Download the fixed list chained cert files
		foreach my $url (@$letsencrypt_chain_urls) {
			my $cout;
			my ($host, $port, $page, $ssl) = &parse_http_url($url);
			my $err;
			&http_download($host, $port, $page, \$cout, \$err,
				       undef, $ssl);
			if ($err) {
				@rv = (0, &text('letsencrypt_echain', $err));
				goto FAILED;
				}
			if ($cout !~ /\S/ && !-r $chain) {
				@rv = (0, &text('letsencrypt_echain2', $url));
				goto FAILED;
				}
			my $fh = "CHAIN";
			&open_tempfile($fh, ">>$chain");
			&print_tempfile($fh, $cout);
			&close_tempfile($fh);
			}
		}

	# Copy the per-domain files
	my $certfinal = "$module_config_directory/$doms[0].cert";
	my $keyfinal = "$module_config_directory/$doms[0].key";
	my $chainfinal = "$module_config_directory/$doms[0].ca";
	&copy_source_dest($cert, $certfinal, 1);
	&copy_source_dest($key, $keyfinal, 1);
	&copy_source_dest($chain, $chainfinal, 1);
	&set_ownership_permissions(undef, undef, 0600, $certfinal);
	&set_ownership_permissions(undef, undef, 0600, $keyfinal);
	&set_ownership_permissions(undef, undef, 0600, $chainfinal);
	&unlink_file($cert);
	&unlink_file($key);
	&unlink_file($chain);

	@rv = (1, $certfinal, $keyfinal, $chainfinal);
	}

# Run the after command
FAILED:
if ($wellknown_new) {
	&cleanup_wellknown($wellknown_new, $challenge_new);
	}
if ($config{'letsencrypt_after'}) {
	&backquote_logged("$config{'letsencrypt_after'} 2>&1 </dev/null");
	}

return @rv;
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
return undef if (!&foreign_installed("bind8"));
&foreign_require("bind8");
my $bd = $d;
while ($bd =~ /\./) {
	my $z = &bind8::get_zone_name($bd, "any");
	if ($z && $z->{'file'} && $z->{'type'} eq 'master') {
		return ($z, $bd);
		}
	$bd =~ s/^[^\.]+\.//;
	}
return ( );
}

# get_virtualmin_for_domain(domain-name)
# If Virtualmin is installed, return the domain object that contains the given DNS domain
sub get_virtualmin_for_domain
{
my ($bd) = @_;
return undef if (!&foreign_check("virtual-server"));
&foreign_require("virtual-server");
while ($bd =~ /\./) {
	my $d = &virtual_server::get_domain_by("dom", $bd);
	if ($d && $d->{'dns'}) {
		return $d;
		}
	$bd =~ s/^[^\.]+\.//;
	}
return undef;
}

# get_certbot_major_version(cmd)
# Returns Let's Encrypt client major version, such as 1.11 or 0.40
sub get_certbot_major_version
{
my ($cmd) = @_;
my $out = &backquote_command("$cmd --version 2>&1");
if ($out && $out =~ /\s*(\d+\.\d+)\s*/) {
	return $1;
	}
return undef;
}

# cleanup_letsencrypt_files(domain)
# Delete all temporary files under /etc/letsencrypt for a domain name
sub cleanup_letsencrypt_files
{
my ($dname) = @_;
foreach my $base ("/etc/letsencrypt", "/usr/local/etc/letsencrypt") {
	next if (!-d $base);
	foreach my $f ("$base/live/$dname",
		       glob("$base/live/$dname-[0-9][0-9][0-9][0-9]"),
		       "$base/archive/$dname",
                       glob("$base/archive/$dname-[0-9][0-9][0-9][0-9]"),
		       "$base/renewal/$dname.conf",
		       glob("$base/renewal/$dname-[0-9][0-9][0-9][0-9].conf")) {
		&unlink_file($f) if (-e $f);
		}
	}
}

1;
