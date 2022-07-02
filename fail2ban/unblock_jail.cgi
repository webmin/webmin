#!/usr/local/bin/perl
# Create, update or delete a action

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'status_err_set'});

my @jails = split(/\0/, $in{'jail'});

# Error checks
@jails || &error($text{'status_err_nojail'});

# Processes jails actions
my @jailsmod;
foreach my $jail (@jails) {
	my @jailips = split(/\s+/, $in{"jips-$jail"});
	if (@jailips) {
		foreach my $ip (@jailips) {
			&unblock_jailed_ip($jail, $ip);
			push(@jailsmod, $jail);
			}
		}
	}

# Log and redirect
&webmin_log('update', 'jail', join(", ", &unique(@jailsmod))) if (@jailsmod);
&redirect("list_status.cgi");
