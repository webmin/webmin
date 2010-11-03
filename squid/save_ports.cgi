#!/usr/local/bin/perl
# save_ports.cgi
# Save ports and other networking options

require './squid-lib.pl';
$access{'portsnets'} || &error($text{'eports_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'sport_ftspo'};

if ($squid_version >= 2.3 && $in{'ports_def'}) {
	&save_directive($conf, 'http_port', [ ]);
	}
elsif ($squid_version >= 2.3) {
	&save_ports("http_port");
	if ($squid_version >= 2.5) {
		&save_ports("https_port");
		}
	}
else {
	&save_opt("http_port", \&check_port, $conf);
	&save_opt("tcp_incoming_address", \&check_address, $conf);
	}
&save_opt("icp_port", \&check_port, $conf);
&save_opt("tcp_outgoing_address", \&check_address, $conf);
&save_opt("udp_outgoing_address", \&check_address, $conf);
&save_opt("udp_incoming_address", \&check_address, $conf);
if (!$in{'udp_outgoing_address_def'} && !$in{'udp_incoming_address_def'} &&
     $in{'udp_outgoing_address'} eq $in{'udp_incoming_address'}) {
	&error("The outgoing and incoming UDP addresses cannot be the same");
	}
&save_address("mcast_groups", $conf);
&save_opt("tcp_recv_bufsize", \&check_bufsize, $conf);
if ($squid_version >= 2.6) {
	&save_choice("check_hostnames", "on", $conf);
	&save_choice("allow_underscore", "on", $conf);
	}
if ($squid_version >= 2.5) {
	&save_choice("ssl_unclean_shutdown", "off", $conf);
	}
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
return &to_ipaddress($_[0]) || &to_ip6address($_[0]) ? undef :
	&text('sport_emsg2',$_[0]);

}

sub check_bufsize
{
return $_[0] =~ /^\d+$/ ? undef : &text('sport_emsg3',$_[0]);
}

# save_ports(name)
sub save_ports
{
local ($i, $port, $addr, @ports);
for($i=0; defined($port = $in{"$_[0]_port_$i"}); $i++) {
	next if (!$port);
	$port =~ /^\d+$/ || &error("'$port' is not a valid port");
	if ($in{"$_[0]_addr_def_$i"}) {
		push(@ports, { 'name' => $_[0],
			       'values' => [ $port ] } );
		}
	else {
		$addr = $in{"$_[0]_addr_$i"};
		&to_ipaddress($addr) || &to_ip6address($addr) ||
			&error("'$addr' is not a valid proxy address");
		$addr = "[$addr]" if (&check_ip6address($addr));
		push(@ports, { 'name' => $_[0],
			       'values' => [ "$addr:$port" ] } );
		}
	if ($squid_version >= 2.5) {
		push(@{$ports[$#ports]->{'values'}},
		     split(/\s+/, $in{"$_[0]_opts_$i"}));
		}
	}
&save_directive($conf, $_[0], \@ports);
}

