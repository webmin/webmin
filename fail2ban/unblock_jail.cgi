#!/usr/local/bin/perl
# Unblock specific jail

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
	&unblock_jail($jail);
	push(@jailsmod, $jail);
	}

# Log and redirect
&webmin_log('update', 'jail', join(", ", &unique(@jailsmod))) if (@jailsmod);
&redirect("list_status.cgi");
