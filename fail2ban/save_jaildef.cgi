#!/usr/local/bin/perl
# Update default jail options

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'jaildef_err'});

# Find default jail
my @jails = &list_jails();
my ($jail) = grep { $_->{'name'} eq 'DEFAULT' } @jails;
$jail || &error($text{'jaildef_egone'});

# Validate inputs
foreach my $f ("maxretry", "findtime", "bantime") {
	$in{$f.'_def'} || $in{$f} =~ /^\-?\d+$/ ||
		&error($text{'jail_e'.$f});
	}
$in{'destemail_def'} || $in{'destemail'} =~ /^\S+(\@\S+)?$/ ||
	&error($text{'jail_edestemail'});
my @ignoreips = $in{'ignoreip_def'} ? ( ) : split(/\s+/, $in{'ignoreip'});
foreach my $ip (@ignoreips) {
	&check_ipaddress($ip) || &check_ip6address($ip) ||
	    ($ip =~ /^([0-9\.]+)\/(\d+)/ && &check_ipaddress("$1")) ||
	    &to_ipaddress($ip) ||
		&error($text{'jail_eignoreip'});
	}


# Update the jail
&lock_all_config_files();
foreach my $f ("maxretry", "findtime", "bantime") {
	&save_directive($f, $in{$f."_def"} ? undef : $in{$f}, $jail);
	}
&save_directive("ignoreip", @ignoreips ? join(" ", @ignoreips) : undef, $jail);
&save_directive("backend", $in{'backend'} || undef, $jail);
&save_directive("destemail", $in{'destemail_def'} ? undef : $in{'destemail'},
		$jail);
&save_directive("banaction", $in{'banaction'} || undef, $jail);
&save_directive("protocol", $in{'protocol'} || undef, $jail);
&unlock_all_config_files();

&webmin_log("jaildef");
&redirect("list_jails.cgi");
