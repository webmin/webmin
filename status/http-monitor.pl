# http-monitor.pl
# Monitor a remote HTTP server

sub default_http_codes
{
return (200, 301, 302, 303, 307, 308);
}

sub get_http_status
{
local ($o) = @_;
local $up = 0;
local $st = time();
local $desc;
eval {
	# Connect to the server
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	alarm($o->{'alarm'} ? $o->{'alarm'} : 10);

	local $re = $o->{'regexp'};
	local $method = $o->{'method'} || "HEAD";
	local $con = &make_http_connection(
			$o->{'ip'} || $o->{'host'}, $o->{'port'},
			$o->{'ssl'}, $method, $o->{'page'});
	if (!ref($con)) {
		$up = 0;
		$desc = $con;
		return;
		}
	&write_http_connection($con, "Host: $o->{'host'}\r\n");
	&write_http_connection($con, "User-agent: Webmin\r\n");
	if ($o->{'user'}) {
		local $auth = &encode_base64("$o->{'user'}:$o->{'pass'}");
		$auth =~ s/\n//g;
		&write_http_connection($con, "Authorization: Basic $auth\r\n");
		}
	&write_http_connection($con, "\r\n");
	local $line = &read_http_connection($con);
	local @codes = $o->{'codes'} ? split(/\s+/, $o->{'codes'})
				     : &default_http_codes();
	local $cre = join("|", @codes);
	if ($line =~ /^HTTP\/1\..\s+($cre)\s+/) {
		$up = 1;
		}
	else {
		$desc = "Bad HTTP status line : $line";
		}
	if ($re && $up) {
		# Read the headers
		local %header;
		while(1) {
			$line = &read_http_connection($con);
			$line =~ tr/\r\n//d;
			$line =~ /^(\S+):\s+(.*)$/ || last;
			$header{lc($1)} = $2;
			}

		# Read the body
		local ($buf, $data);
		while(defined($buf = &read_http_connection($con))) {
			$data .= $buf;
			}
		eval {
			# Check for regexp match
			eval {
				if ($data !~ /$re/i) {
					$up = 0;
					$desc = "No match on : $re";
					}
				};
			};
		}

	&close_http_connection($con);
	alarm(0);
	};

if ($@) {
	die unless $@ eq "alarm\n";   # propagate unexpected errors
	return { 'up' => 0,
		 'desc' => $desc };
	}
else { 
	return { 'up' => $up,
		 'time' => time() - $st,
		 'desc' => $desc };
	}
}

sub show_http_dialog
{
local ($o) = @_;
local $url;
if ($o->{'host'}) {
	$url = ($o->{'ssl'} ? "https" : "http")."://";
	if (&check_ip6address($o->{'host'})) {
		$url .= "[".$o->{'host'}."]";
		}
	else {
		$url .= $o->{'host'};
		}
	$url .= ":$o->{'port'}$o->{'page'}";
	}
else {
	$url = "http://";
	}
print &ui_table_row($text{'http_url'},
	&ui_textbox("url", $url, 50), 3);

print &ui_table_row($text{'http_alarm'},
	&ui_opt_textbox("alarm", $o->{'alarm'}, 5, $text{'default'}).
	" ".$text{'oldfile_secs'});

print &ui_table_row($text{'http_method'},
	&ui_select("method", $o->{'method'},
		   [ [ "HEAD" ], [ "GET" ], [ "POST" ] ]));

print &ui_table_row($text{'http_login'},
	&ui_radio("user_def", $o->{'user'} ? 0 : 1,
		[ [ 1, $text{'http_none'} ],
		  [ 0, $text{'http_user'}." ".
		       &ui_textbox("huser", $o->{'user'}, 15)." ".
		       $text{'http_pass'}." ".
		       &ui_password("hpass", $o->{'pass'}, 15) ] ]), 3);

print &ui_table_row($text{'http_regexp'},
	&ui_opt_textbox("regexp", $o->{'regexp'}, 50, $text{'http_none2'}),
	3);

print &ui_table_row($text{'http_codes'},
	&ui_opt_textbox("codes", $o->{'codes'}, 50,
		&text('http_codes_def', join(' ', &default_http_codes()))), 3);
}

sub parse_http_dialog
{
local ($o) = @_;
local ($host, $port, $page, $ssl) = &parse_http_url($in{'url'});
if ($host) {
	$o->{'ssl'} = $ssl;
	$o->{'host'} = $host;
	$o->{'port'} = $port;
	$o->{'page'} = $page;
	}
else {
	&error($text{'http_eurl'});
	}

if ($in{'alarm_def'}) {
	delete($o->{'alarm'});
	}
else {
	$in{'alarm'} =~ /^\d+$/ || &error($text{'http_ealarm'});
	$o->{'alarm'} = $in{'alarm'};
	}

if ($in{'user_def'}) {
	delete($o->{'user'});
	delete($o->{'pass'});
	}
else {
	$in{'huser'} || &error($text{'http_euser'});
	$o->{'user'} = $in{'huser'};
	$o->{'pass'} = $in{'hpass'};
	}

$o->{'method'} = $in{'method'};

if ($in{'regexp_def'}) {
	delete($o->{'regexp'});
	}
else {
	$in{'regexp'} || &error($text{'http_eregexp'});
	$o->{'regexp'} = $in{'regexp'};
	$in{'method'} eq 'HEAD' && &error($text{'http_ehead'});
	}

if ($in{'codes_def'}) {
	delete($o->{'codes'});
	}
else {
	my @codes = split(/\s+/, $in{'codes'});
	@codes || &error($text{'http_ecodes'});
	foreach my $c (@codes) {
		$c =~ /^[0-9]{3}$/ || &error($text{'http_ecodes3'});
		}
	$o->{'codes'} = join(" ", @codes);
	}
}

