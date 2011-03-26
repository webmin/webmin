#!/usr/bin/perl
# save_spoof.cgi
# Save spoofing settings

require './itsecur-lib.pl';
&can_edit_error("spoof");
&lock_itsecur_files();
&ReadParse();

&error_setup($text{'spoof_err'});
if ($in{'spoof'}) {
	$iface = $in{'iface'} || $in{'iface_other'};
	$iface =~ /^[a-z0-9:\.]+$/ || &error($text{'nat_eiface'});
	}
else {
	}
@nets = split(/\s+/, $in{'nets'});
foreach $n (@nets) {
	$n =~ /^([0-9\.]+)\/(\d+)$/ &&
		$2 >= 0 && $2 <= 32 &&
		&check_ipaddress("$1") ||
			&error(&text('spoof_enet', $n));
	}
!$iface || @nets || &error($text{'spoof_enets'});
&automatic_backup();
&save_spoof($iface, @nets);
&unlock_itsecur_files();
&remote_webmin_log("update", "spoof");
&redirect("");

