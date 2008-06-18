#!/usr/local/bin/perl
# De-activate a bunch of active interfaces

require './net-lib.pl';

&ReadParse();

&error_setup($text{'daifcs_err'});

@d = split(/\0/, $in{'d'});
@d || &error($text{'daifcs_enone'});

# Do the deletion, one by one
@acts = &active_interfaces();
foreach $d (@d) {
	($a) = grep { $_->{'fullname'} eq $d } @acts;
	$a || &error($text{'daifcs_egone'});
	&can_iface($a) || &error($text{'ifcs_ecannot_this'});
	&deactivate_interface($a);
	}

&webmin_log("delete", "aifcs", scalar(@d));
&redirect("list_ifcs.cgi?mode=active");

