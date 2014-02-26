#!/usr/local/bin/perl
# save_ports.cgi
# Save ports and other networking options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'portsnets'} || &error($text{'eports_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'sport_ftspo'});

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
my ($name) = @_;
my ($i, $port, $addr, @ports);
for($i=0; defined($port = $in{$name."_port_".$i}); $i++) {
	next if (!$port);
	$port =~ /^\d+$/ || &error("'$port' is not a valid port");
	if ($in{$name."_addr_def_".$i}) {
		push(@ports, { 'name' => $name,
			       'values' => [ $port ] } );
		}
	else {
		$addr = $in{$name."_addr_".$i};
		&to_ipaddress($addr) || &to_ip6address($addr) ||
			&error("'$addr' is not a valid proxy address");
		$addr = "[$addr]" if (&check_ip6address($addr));
		push(@ports, { 'name' => $name,
			       'values' => [ "$addr:$port" ] } );
		}
	if ($squid_version >= 2.5) {
		push(@{$ports[$#ports]->{'values'}},
		     split(/\s+/, $in{$name."_opts_".$i}));
		}
	}
&save_directive($conf, $name, \@ports);
}

