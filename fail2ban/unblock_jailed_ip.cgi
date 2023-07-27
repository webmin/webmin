#!/usr/local/bin/perl
# Unblock specific IP in jail

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'status_err_set'});

my $jail = $in{'jail'};
my @ips = split(/\0/, $in{'ip'});

# Error checks
$jail || &error($text{'status_err_nojail'});
@ips || &error($text{'status_err_noips'});

# Processes jails actions
my @jailips;
foreach my $ip (@ips) {
		&unblock_jailed_ip($jail, $ip);
		push(@jailips, $ip);
	}

# Log and redirect
&webmin_log('update', 'jail', $jail) if (@jailips);
&redirect($in{'return'} ? &get_referer_relative() : "list_status.cgi");
