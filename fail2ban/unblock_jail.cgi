#!/usr/local/bin/perl
# Create, update or delete a action

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'status_err_set'});

my @jails = split(/\0/, $in{'jail'});
my $action = $in{'permblock'} ? 'block' : $in{'unblock'} ? 'unblock' : undef;

# Error checks
!$action || $in{'jail'} || &error($text{'status_err_nojail'});

# Unblock given IP in given jail
my $unblock_jailed_ip = sub {
	my ($jail, $ip) = @_;
	my $cmd = "$config{'client_cmd'} set ".quotemeta($jail)." unbanip ".quotemeta($ip)." 2>&1 </dev/null";
	my $out = &backquote_logged($cmd);
	if ($?) {
		&error(&text('status_err_unban', &html_escape($ip)) . " : $out");
		}
};

# Processes jails actions
foreach my $jail (@jails) {
	my @jailips = split(/\s+/, $in{"jips-$jail"});
	if (@jailips) {
		foreach my $ip (@jailips) {
			# Blocking permanently IP from given jail
			if ($action eq 'block') {
				# Add permanent block first
				&foreign_require('firewalld');
				my $out = &firewalld::add_ip_ban($ip);
				if ($out) {
					&error(&text('status_err_ban', &html_escape($ip)) . " : $out");
				}
				# Remove from fail2ban now
				&$unblock_jailed_ip($jail, $ip);
				}
			# Unblocking IP from given jail
			elsif ($action eq 'unblock') {
				# Just unblock
				&$unblock_jailed_ip($jail, $ip);
				}
			}
		}
	}

# Log and redirect
&webmin_log('update', 'jail', join(", ", @jails));
&redirect("list_status.cgi");
