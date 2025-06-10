#!/usr/local/bin/perl
# Attempt a PPTP connection

$no_acl_check++;
require './pptp-client-lib.pl';

# Get tunnel details
@tunnels = &list_tunnels();
($tunnel) = grep { $_->{'name'} eq $config{'boot'} } @tunnels;
$tunnel || die $text{'conn_egone'};
&parse_comments($tunnel);
$tunnel->{'server'} || die $text{'conn_einvalid'};

# Check if it is already active
@conns = &list_connected();
($conn) = grep { $_->[0] eq $config{'boot'} } @conns;
$conn && die $text{'conn_ealready'};

print &text('conn_cmd',
	    "$config{'pptp'} $tunnel->{'server'} call $config{'boot'}"),"\n";
($ok, @status) = &connect_tunnel($tunnel);
if ($ok) {
	print &text('conn_ok', $status[0], $status[1], $status[2]),"\n";
	exit(0);
	}
else {
	print "$text{'conn_timeout'}\n";
	print "$status[0]\n";
	exit(1);
	}

