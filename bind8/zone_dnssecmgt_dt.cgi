#!/usr/local/bin/perl
# Perform one of a number of DNSSEC-related operations for the zone 
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';

&error_setup($text{'dt_zone_err'});
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'dnssec'} || &error($text{'dnssec_ecannot'});

if (&have_dnssec_tools_support()) {
	my $err;
	my $optype = $in{'optype'};
	if ($optype eq "resign") {
		# Do the signing
		#$zonefile = &make_chroot(&absolute_path($zone->{'file'}));
		my $zonefile = &get_zone_file($zone);
		my $krfile = "$zonefile".".krf";
		&lock_file(&make_chroot($zonefile));
		$err = &dt_resign_zone($dom, $zonefile, $krfile, 0);
		&unlock_file(&make_chroot($zonefile));
		&error($err) if ($err);
	} elsif ($optype eq "zskroll") {
		$err = &dt_zskroll_zone($dom);
		&error($err) if ($err);
	} elsif ($optype eq "kskroll") {
		$err = &dt_kskroll_zone($dom);
		&error($err) if ($err);
	} elsif ($optype eq "notify") {
		$err = &dt_notify_parentzone($dom);
		&error($err) if ($err);
	} elsif ($optype eq "rollerdrst") {
		$err = &dt_rollerd_restart();
		&error($err) if ($err);
	}

	&webmin_log("manage", undef, $dom);
}

# Return to master page
&redirect("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}");

