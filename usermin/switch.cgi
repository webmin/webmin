#!/usr/local/bin/perl
# Set the Usermin session cookie to be some other user

require './usermin-lib.pl';
&ReadParse();
$access{'sessions'} || &error($text{'switch_euser'});

&get_usermin_miniserv_config(\%miniserv);
if (&check_pid_file($miniserv{'pidfile'})) {
	# Stop Usermin first, so that the DBM can be safely written
	&stop_usermin();
	$stopped = 1;
	}
&acl::open_session_db(\%miniserv);
&seed_random();
$now = time();
$sid = int(rand()*$now);
$acl::sessiondb{$sid} = "$in{'user'} $now $ENV{'REMOTE_ADDR'}";
dbmclose(%acl::sessiondb);
if ($stopped) {
	&start_usermin();
	}
&reload_usermin_miniserv();
&webmin_log("switch", undef, $in{'user'});
eval "use Net::SSLeay";
if ($@) {
	$miniserv{'ssl'} = 0;
	}
$ssl = $miniserv{'ssl'} || $miniserv{'inetd_ssl'};
$sec = $ssl ? "; secure" : "";
$sidname = $miniserv{'sidname'} || 'sid';
print "Set-Cookie: $sidname=$sid; path=/$sec\n";

# Work out redirect host
@sockets = &webmin::get_miniserv_sockets(\%miniserv);
if ($config{'host'}) {
	# Specific hostname set
	$host = $config{'host'};
	}
else {
	if ($sockets[0]->[0] ne "*") {
		# Listening on special IP
		$host = $sockets[0]->[0];
		$port = $sockets[0]->[1] if ($sockets[0]->[1] ne '*');
		}
	else {
		# Use same hostname as this server
		$host = $ENV{'HTTP_HOST'};
		$host =~ s/:.*//;
		}
	}
$port ||= $config{'port'} || $miniserv{'port'};

&redirect(($ssl ? "https://" : "http://").
	  $host.":".$port."/");

