# tcp-monitor.pl
# Monitor a remote TCP server

sub get_tcp_status
{
# Connect to the server
socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname("tcp")) ||
	return { 'up' => -1 };
local $addr = inet_aton($_[0]->{'host'});
return { 'up' => -1 } if (!$addr);
local $st = time();
local $rv;
eval {
	local $SIG{'ALRM'} = sub { die "alarm\n" };
	alarm($_[0]->{'alarm'} ? $_[0]->{'alarm'} : 10);
	$rv = connect(SOCK, pack_sockaddr_in($_[0]->{'port'}, $addr));
	close(SOCK);
	alarm(0);
	};
return { 'up' => 0 } if ($@);
return { 'up' => $rv,
	 'time' => time() - $st };
}

sub show_tcp_dialog
{
print &ui_table_row($text{'tcp_host'},
	&ui_textbox("host", $_[0]->{'host'}, 25));

print &ui_table_row($text{'tcp_port'},
	&ui_textbox("port", $_[0]->{'port'}, 5));

print &ui_table_row($text{'tcp_alarm'},
	&ui_opt_textbox("alarm", $_[0]->{'alarm'}, 5, $text{'default'}));
}

sub parse_tcp_dialog
{
&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'tcp_ehost'});
$_[0]->{'host'} = $in{'host'};

$in{'port'} =~ /^\d+$/ || &error($text{'tcp_eport'});
$_[0]->{'port'} = $in{'port'};

if ($in{'alarm_def'}) {
	delete($_[0]->{'alarm'});
	}
else {
	$in{'alarm'} =~ /^\d+$/ || &error($text{'tcp_ealarm'});
	$_[0]->{'alarm'} = $in{'alarm'};
	}
}

1;

