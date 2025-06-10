#!/usr/local/bin/perl
# save_net.cgi
# Save global address and topology options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'net_ecannot'});
&error_setup($text{'net_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my $options = &find("options", $conf);
my %used;
my @listen;
my @listen6;
if (!$in{'listen_def'}) {
	my $addr;
	for(my $i=0; defined($addr = $in{"addrs_$i"}); $i++) {
		next if (!$in{"proto_$i"});
		my $l = { 'name' => $in{"proto_$i"} eq 'v6' ?
				'listen-on-v6' : 'listen-on',
			  'values' => [ ],
			  'type' => 1 };
		if (!$in{"pdef_$i"}) {
			$in{"port_$i"} =~ /^\d+$/ ||
				&error(&text('net_eport', $in{"port_$i"}));
			push(@{$l->{'values'}}, 'port', $in{"port_$i"});
			}
		if ($in{"tls_$i"}) {
			push(@{$l->{'values'}}, 'tls', $in{"tls_$i"});
			}
		my $port = $in{"pdef_$i"} ? 53 : $in{"port_$i"};
		$used{$port,$l->{'name'}}++ &&
			&error(&text('net_eusedport', $port));
		$l->{'members'} =
			[ map { { 'name' => $_ } } split(/\s+/, $addr) ];
		if ($l->{'name'} eq 'listen-on') {
			push(@listen, $l);
			}
		else {
			push(@listen6, $l);
			}
		}
	}
&save_directive($options, 'listen-on', \@listen, 1);
&save_directive($options, 'listen-on-v6', \@listen6, 1);

# Save query source address and port
my @qvals;
if (!$in{'saddr_def'}) {
	&check_ipaddress($in{'saddr'}) ||
		&error(&text('net_eaddr', $in{'saddr'}));
	push(@qvals, "address", $in{'saddr'});
	}
if (!$in{'sport_def'}) {
	$in{'sport'} =~ /^\d+$/ || &error(&text('net_eport', $in{'sport'}));
	push(@qvals, "port", $in{'sport'});
	}
if (@qvals) {
	&save_directive($options, 'query-source',
			[ { 'name' => 'query-source',
			    'values' => \@qvals } ], 1);
	}
else {
	&save_directive($options, 'query-source', [ ], 1);
	}

# Save IPv4 transfer source address and port
my @tvals;
if ($in{'taddr_def'} == 0) {
	&check_ipaddress($in{'taddr'}) ||
		&error(&text('net_eaddr', $in{'taddr'}));
	push(@tvals, $in{'taddr'});
	}
elsif ($in{'taddr_def'} == 2) {
	push(@tvals, "*");
	}
if ($in{'tport_def'} == 0) {
	@tvals || &error($text{'net_etport'});
	$in{'tport'} =~ /^\d+$/ || &error(&text('net_eport', $in{'sport'}));
	push(@tvals, "port", $in{'tport'});
	}
if (@tvals) {
	&save_directive($options, 'transfer-source',
			[ { 'name' => 'transfer-source',
			    'values' => \@tvals } ], 1);
	}
else {
	&save_directive($options, 'transfer-source', [ ], 1);
	}

# Save IPv6 transfer source address and port
my @tvals6;
if ($in{'taddr6_def'} == 0) {
	&check_ip6address($in{'taddr6'}) ||
		&error(&text('net_eaddr6', $in{'taddr6'}));
	push(@tvals6, $in{'taddr6'});
	}
elsif ($in{'taddr6_def'} == 2) {
	push(@tvals6, "*");
	}
if ($in{'tport6_def'} == 0) {
	@tvals6 || &error($text{'net_etport'});
	$in{'tport6'} =~ /^\d+$/ || &error(&text('net_eport', $in{'sport'}));
	push(@tvals6, "port", $in{'tport6'});
	}
if (@tvals6) {
	&save_directive($options, 'transfer-source-v6',
			[ { 'name' => 'transfer-source-v6',
			    'values' => \@tvals6 } ], 1);
	}
else {
	&save_directive($options, 'transfer-source-v6', [ ], 1);
	}



$in{'topology_def'} || $in{'topology'} || &error($text{'net_etopology'});
&save_addr_match('topology', $options, 1);
$in{'allow-recursion_def'} || $in{'allow-recursion'} ||
	&error($text{'net_erecur'});
&save_addr_match('allow-recursion', $options, 1);

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("net", undef, undef, \%in);
&redirect("");
