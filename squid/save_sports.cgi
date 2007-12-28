#!/usr/local/bin/perl
# save_sports.cgi
# Save simple ports and other networking options

require './squid-lib.pl';
$access{'portsnets'} || &error($text{'eports_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'sport_ftspo'};

if ($squid_version >= 2.3) {
	for($i=0; defined($port = $in{"port_$i"}); $i++) {
		next if (!$port);
		$port =~ /^\d+$/ || &error("'$port' is not a valid port");
		if ($in{"addr_def_$i"}) {
			push(@ports, { 'name' => 'http_port',
				       'values' => [ $port ] } );
			}
		else {
			$addr = $in{"addr_$i"};
			gethostbyname($addr) || &check_ipaddress($addr) ||
				&error("'$addr' is not a valid proxy address");
			push(@ports, { 'name' => 'http_port',
				       'values' => [ "$addr:$port" ] } );
			}
		}
	&save_directive($conf, 'http_port', \@ports);
	}
else {
	&save_opt("http_port", \&check_port, $conf);
	&save_opt("tcp_incoming_address", \&check_address, $conf);
	}

&save_opt("dns_testnames", undef, $conf);

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("ports", undef, undef, \%in);
&redirect("");

sub check_port
{
return $_[0] =~ /^\d+$/ ? undef : &text('sport_emsg1',$_[0]);
}

sub check_address
{
return &check_ipaddress($_[0]) || gethostbyname($_[0]) ? undef :
	&text('sport_emsg2',$_[0]);

}

sub check_bufsize
{
return $_[0] =~ /^\d+$/ ? undef : &text('sport_emsg3',$_[0]);
}

