# Check the status of a SSL cert on a remote server

sub get_sslcert_status
{
local $up = 0;
local $desc;
eval "use Net::SSLeay";

# Parse the URL and connect
local ($host, $port, $page, $ssl) = &parse_http_url($_[0]->{'url'});

# Run the openssl command to connect
local $cmd = "openssl s_client -host ".quotemeta($host).
	     " -port ".quotemeta($port)." </dev/null 2>&1";
local $out = &backquote_with_timeout($cmd, 10);
if ($?) {
	# Connection failed
	return { 'up' => -1 };
	}

# Extract the cert part and save
local $temp = &transname();
if ($out =~ /(-----BEGIN CERTIFICATE-----\n(.*\n)+-----END CERTIFICATE-----\n)/) {
	local $cert = $1;
	print STDERR "cert=$cert\n";
	&open_tempfile(CERT, ">$temp", 0, 1);
	&print_tempfile(CERT, $cert);
	&close_tempfile(CERT);
	}
else {
	# No cert?
	return { 'up' => 0,
		 'desc' => $text{'sslcert_ecert'} };
	}

# Get end date with openssl x509 -in cert.pem -inform PEM -text -noout -enddate 
local $info = &backquote_command("openssl x509 -in ".quotemeta($temp).
				 " -inform PEM -text -noout -enddate ".
				 " </dev/null 2>&1");
print STDERR "info=$info\n";

# Check dates
# XXX (before and after)

$up = 1;

return { 'up' => $up, 'desc' => $desc };
}

sub show_sslcert_dialog
{
# URK to check
print &ui_table_row($text{'sslcert_url'},
	&ui_textbox("url", $_[0]->{'url'}, 50), 3);

# Days before expiry to warn
print &ui_table_row($text{'sslcert_days'},
	&ui_opt_textbox("days", $_[0]->{'days'}, 5, $text{'sslcert_when'}));

# Warn about mismatch
print &ui_table_row($text{'sslcert_mismatch'},
	&ui_yesno_radio("mismatch", $_[0]->{'mismatch'}));
}

sub parse_sslcert_dialog
{
# Parse URL
$in{'url'} =~ /^https:\/\/(\S+)$/ || &error($text{'sslcert_eurl'});
$_[0]->{'url'} = $in{'url'};

# Parse number of days
if ($in{'days_def'}) {
	delete($_[0]->{'days'});
	}
else {
	$in{'days'} =~ /^[1-9]\d*$/ || &error($text{'sslcert_edays'});
	$_[0]->{'days'} = $in{'days'};
	}

# Check hostname
$_[0]->{'mismatch'} = $in{'mismatch'};
}

