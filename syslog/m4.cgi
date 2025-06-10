#!/usr/local/bin/perl
# m4.cgi
# Pass the syslog config file though m4

require './syslog-lib.pl';
use Socket;

# is this loghost? Find out by sending a UDP packet to it
socket(UDP, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
setsockopt(UDP, SOL_SOCKET, SO_BROADCAST, pack("l", 1));
$port = 45678;
while(!bind(UDP, pack_sockaddr_in($port, INADDR_ANY))) {
	$port++;
	}
send(UDP, "foo", 0, pack_sockaddr_in($port, inet_aton("loghost")));
vec($rin, fileno(UDP), 1) = 1;
if (select($rin, undef, undef, 1)) {
	$args .= " -DLOGHOST";
	}
close(UDP);

# Run m4
$oldslash = $/;
$/ = undef;
open(CONF, "$config{'m4_path'} $args $config{'syslog_conf'} |");
$conf = <CONF>;
close(CONF);
&open_tempfile(CONF, ">$config{'syslog_conf'}");
&print_tempfile(CONF, $conf);
&close_tempfile(CONF);
$/ = $oldslash;
&redirect("");

