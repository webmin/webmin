# http-monitor.pl
# Monitor a remote HTTP server

sub get_http_status
{
# Connect to the server
local $up=0;
local $st = time();
eval {
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	alarm($_[0]->{'alarm'} ? $_[0]->{'alarm'} : 10);

	local $re = $_[0]->{'regexp'};
	local $method = $_[0]->{'method'} || "HEAD";
	local $con = &make_http_connection($_[0]->{'host'}, $_[0]->{'port'},
				   $_[0]->{'ssl'}, $method, $_[0]->{'page'});
	if (!ref($con)) {
		return { 'up' => 0 };
		}
	&write_http_connection($con, "Host: $_[0]->{'host'}\r\n");
	&write_http_connection($con, "User-agent: Webmin\r\n");
	if ($_[0]->{'user'}) {
		local $auth = &encode_base64("$_[0]->{'user'}:$_[0]->{'pass'}");
		$auth =~ s/\n//g;
		&write_http_connection($con, "Authorization: basic $auth\r\n");
		}
	&write_http_connection($con, "\r\n");
	local $line = &read_http_connection($con);
	$up = $line =~ /^HTTP\/1\..\s+(200|301|302)\s+/ ? 1 : 0;
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
		if ($data !~ /$re/i) {
			$up = 0;
			}
		}

	&close_http_connection($con);
	alarm(0);
	};

if ($@) {
	die unless $@ eq "alarm\n";   # propagate unexpected errors
	return { 'up' => 0 };
	}
else { 
	return { 'up' => $up, 'time' => time() - $st};
	}
}

sub show_http_dialog
{
local $url = $_[0]->{'host'} ? ($_[0]->{'ssl'} ? "https" : "http").
	     		    "://$_[0]->{'host'}:$_[0]->{'port'}$_[0]->{'page'}"
			     : "http://";
print &ui_table_row($text{'http_url'},
	&ui_textbox("url", $url, 50), 3);

print &ui_table_row($text{'http_alarm'},
	&ui_opt_textbox("alarm", $_[0]->{'alarm'}, 5, $text{'default'}));

print &ui_table_row($text{'http_method'},
	&ui_select("method", $_[0]->{'method'},
		   [ [ "HEAD" ], [ "GET" ], [ "POST" ] ]));

print &ui_table_row($text{'http_login'},
	&ui_radio("user_def", $_[0]->{'user'} ? 0 : 1,
		[ [ 1, $text{'http_none'} ],
		  [ 0, $text{'http_user'}." ".
		       &ui_textbox("huser", $_[0]->{'user'}, 15)." ".
		       $text{'http_pass'}." ".
		       &ui_password("hpass", $_[0]->{'pass'}, 15) ] ]), 3);

print &ui_table_row($text{'http_regexp'},
	&ui_opt_textbox("regexp", $_[0]->{'regexp'}, 50, $text{'http_none2'}),
	3);
}

sub parse_http_dialog
{
if ($in{'url'} =~ /^(http|https):\/\/([^:]+):(\d+)(\/.*)$/) {
	$_[0]->{'ssl'} = $1 eq "https";
	$_[0]->{'host'} = $2;
	$_[0]->{'port'} = $3;
	$_[0]->{'page'} = $4;
	}
elsif ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
	$_[0]->{'ssl'} = $1 eq "https";
	$_[0]->{'host'} = $2;
	$_[0]->{'port'} = $1 eq "https" ? 443 : 80;
	$_[0]->{'page'} = $3;
	}
elsif ($in{'url'} =~ /^(http|https):\/\/([^:]+):(\d+)$/) {
	$_[0]->{'ssl'} = $1 eq "https";
	$_[0]->{'host'} = $2;
	$_[0]->{'port'} = $3;
	$_[0]->{'page'} = "/";
	}
elsif ($in{'url'} =~ /^(http|https):\/\/([^\/]+)$/) {
	$_[0]->{'ssl'} = $1 eq "https";
	$_[0]->{'host'} = $2;
	$_[0]->{'port'} = $1 eq "https" ? 443 : 80;
	$_[0]->{'page'} = "/";
	}
else {
	&error($text{'http_eurl'});
	}

if ($in{'alarm_def'}) {
	delete($_[0]->{'alarm'});
	}
else {
	$in{'alarm'} =~ /^\d+$/ || &error($text{'http_ealarm'});
	$_[0]->{'alarm'} = $in{'alarm'};
	}

if ($in{'user_def'}) {
	delete($_[0]->{'user'});
	delete($_[0]->{'pass'});
	}
else {
	$in{'user'} || &error($text{'http_euser'});
	$_[0]->{'user'} = $in{'huser'};
	$_[0]->{'pass'} = $in{'hpass'};
	}

$_[0]->{'method'} = $in{'method'};

if ($in{'regexp_def'}) {
	delete($_[0]->{'regexp'});
	}
else {
	$in{'regexp'} || &error($text{'http_eregexp'});
	$_[0]->{'regexp'} = $in{'regexp'};
	$in{'method'} eq 'HEAD' && &error($text{'http_ehead'});
	}
}

