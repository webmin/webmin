#!/usr/local/bin/perl
# Add a new network interface

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'iadd_err'});

# Check for a clash
my $ifaces = &list_iscsi_ifaces();
ref($ifaces) || &error(&text('ifaces_elist', $ifaces));
my ($clash) = grep { $_->{'name'} eq $in{'name'} } @$ifaces;
$clash && &error(&text('iadd_eclash', $in{'name'}));

# Validate and store inputs
$in{'name'} =~ /^[a-z0-9\.\_\-]+$/ || &error($text{'iadd_ename'});
my $iface = { 'name' => $in{'name'} };
$iface->{'iface.transport_name'} = $in{'transport'};
if (!$in{'ipaddress_def'}) {
	&check_ipaddress($in{'ipaddress'}) ||
		&error($text{'iadd_eipaddress'});
	$iface->{'iface.ipaddress'} = $in{'ipaddress'};
	}
if (!$in{'hwaddress_def'}) {
	$in{'hwaddress'} =~ /^[A-Fa-f0-9:]+$/ ||
		&error($text{'iadd_ehwaddress'});
	$iface->{'iface.hwaddress'} = $in{'hwaddress'};
	}
if ($in{'ifacename'}) {
	$iface->{'iface.net_ifacename'} = $in{'ifacename'};
	}

# Create to add the interface
my $err = &create_iscsi_interface($iface);
&error($err) if ($err);

&webmin_log("add", "iface", $in{'name'}, $iface);
&redirect("list_ifaces.cgi");
