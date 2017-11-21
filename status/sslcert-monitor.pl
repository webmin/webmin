# Check the status of a SSL cert on a remote server

sub get_sslcert_status
{
local $up = 0;
local $desc;
local $certfile;
local ($host, $port, $page, $ssl);

if ($_[0]->{'url'}) {
	# Parse the URL and connect
	($host, $port, $page, $ssl) = &parse_http_url($_[0]->{'url'});

	# Run the openssl command to connect
	local $cmd = "openssl s_client -host ".quotemeta($host).
		     " -servername ".quotemeta($host).
		     " -port ".quotemeta($port)." </dev/null 2>&1";
	local $out = &backquote_with_timeout($cmd, 10);
	if ($?) {
		# Try again without -servername, as some openssl versions
		# don't support it
		$cmd = "openssl s_client -host ".quotemeta($host).
		       " -port ".quotemeta($port)." </dev/null 2>&1";
		$out = &backquote_with_timeout($cmd, 10);
		}
	if ($?) {
		# Connection failed
		return { 'up' => -1,
			 'desc' => $text{'sslcert_edown'} };
		}

	# Extract the cert part and save
	$certfile = &transname();
	if ($out =~ /(-----BEGIN CERTIFICATE-----\n(.*\n)+-----END CERTIFICATE-----\n)/) {
		local $cert = $1;
		&open_tempfile(CERT, ">$certfile", 0, 1);
		&print_tempfile(CERT, $cert);
		&close_tempfile(CERT);
		}
	else {
		# No cert?
		return { 'up' => 0,
			 'desc' => $text{'sslcert_ecert'} };
		}
	}
else {
	# Cert is already in a file
	$certfile = $_[0]->{'file'};
	}

# Get end date with openssl x509 -in cert.pem -inform PEM -text -noout -enddate 
local $info = &backquote_command("openssl x509 -in ".quotemeta($certfile).
				 " -inform PEM -text -noout -enddate ".
				 " </dev/null 2>&1");

# Check dates
&foreign_require("mailboxes");
local ($start, $end);
if ($info =~ /Not\s*Before\s*:\s*(.*)/i) {
	$start = &mailboxes::parse_mail_date("$1");
	}
if ($info =~ /Not\s+After\s*:\s*(.*)/i) {
	$end = &mailboxes::parse_mail_date("$1");
	}
local $now = time();
if ($start && $now < $start) {
	# Too new?!
	$desc = &text('sslcert_estart', &make_date($start));
	}
elsif ($end && $now > $end-$_[0]->{'days'}*24*60*60) {
	# Too old
	$desc = &text('sslcert_eend', &make_date($end));
	}
elsif ($_[0]->{'mismatch'} && $_[0]->{'url'} &&
       $info =~ /Subject:.*CN=([a-z0-9\.\-\_\*]+)/i) {
	# Check hostname
	local $cn = $1;
	local $match = $1;
	$match =~ s/\*/\.\*/g;	# Make perl RE
	local @matches = ( $match );
	if ($info =~ /Subject\s+Alternative\s+Name.*\r?\n\s*(.*)\n/) {
		# Add UCC alternate names
		local $alts = $1;
		$alts =~ s/^\s+//;
		$alts =~ s/\s+$//;
		foreach my $a (split(/[, ]+/, $alts)) {
			if ($a =~ /^DNS:(\S+)/) {
				$match = $1;
				$match =~ s/\*/\.\*/g;  # Make perl RE
				push(@matches, $match);
				}
			}
		}
	local $ok = 0;
	foreach $match (@matches) {
		$ok++ if ($host =~ /^$match$/i);
		}
	if (!$ok) {
		$desc = &text('sslcert_ematch', $host, $cn);
		}
	}

if (!$desc) {
	# All OK!
	$desc = &text('sslcert_left', int(($end-$now)/(24*60*60)));
	$up = 1;
	}

return { 'up' => $up, 'desc' => $desc };
}

sub show_sslcert_dialog
{
# URL or file to check
print &ui_table_row($text{'sslcert_src'},
	&ui_radio_table("src", $_[0]->{'file'} ? 1 : 0,
		[ [ 0, $text{'sslcert_url'},
		    &ui_textbox("url", $_[0]->{'url'}, 50) ],
		  [ 1, $text{'sslcert_file'},
		    &ui_textbox("file", $_[0]->{'file'}, 50)." ".
		    &file_chooser_button("file") ] ]), 3);

# Days before expiry to warn
print &ui_table_row($text{'sslcert_days'},
	&ui_opt_textbox("days", $_[0]->{'days'}, 5, $text{'sslcert_when'}));

# Warn about mismatch
print &ui_table_row($text{'sslcert_mismatch'},
	&ui_yesno_radio("mismatch", $_[0]->{'mismatch'}));
}

sub parse_sslcert_dialog
{
&has_command("openssl") || &error($text{'sslcert_eopenssl'});

if ($in{'src'} == 0) {
	# Parse URL
	$in{'url'} =~ /^https:\/\/(\S+)$/ || &error($text{'sslcert_eurl'});
	$_[0]->{'url'} = $in{'url'};
	delete($_[0]->{'file'});
	}
else {
	# Parse file
	$in{'file'} =~ /^\// && -r $in{'file'} ||
		&error($text{'sslcert_efile'});
	$_[0]->{'file'} = $in{'file'};
	delete($_[0]->{'url'});
	}

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
if ($in{'mismatch'} && $in{'src'}) {
	&error($text{'sslcert_emismatch'});
	}
}

