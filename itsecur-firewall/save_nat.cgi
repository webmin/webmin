#!/usr/bin/perl
# save_nat.cgi
# Update NAT setting

require './itsecur-lib.pl';
&can_edit_error("nat");
&ReadParse();
&lock_itsecur_files();

&error_setup($text{'nat_err'});
if ($in{'nat'}) {
	$iface = $in{'iface'} || $in{'iface_other'};
	$iface =~ /^[a-z0-9:\.]+$/ || &error($text{'nat_eiface'});
	}
for($i=0; defined($n = $in{"net_$i"}); $i++) {
	push(@nets, $n) if ($n);
	}
for($i=0; defined($n = $in{"excl_$i"}); $i++) {
	push(@nets, "!$n") if ($n);
	}
local @dests;
for($i=0; defined($e = $in{"ext_$i"}); $i++) {
	next if (!$e);	
	#gethostbyname($e) || &error(&text('nat_eext', $i+1));
	valid_host($e) || &error(&text('nat_eext', $i+1));
	#is_one_host("\@$e") && &error(&text('nat_eext', $i+1));	
	$n = $in{"int_$i"};
	#gethostbyname($n) || &error(&text('nat_eint', $i+1));
	##valid_host($n) || &error(&text('nat_eint', $i+1));	
	is_one_host("\@$n") && &error(&text('nat_eint', $i+1));		
	$v = $in{"virt_$i"};
	push(@maps, [ $e, $n, $v ? ( $v ) : ( ) ]);
	}
&automatic_backup();
&save_nat($iface, @nets, @maps);
&unlock_itsecur_files();
&remote_webmin_log("update", "nat");
&redirect("");

