#!/usr/bin/perl
# save_pat.cgi
# Save incoming forwarded ports

require './itsecur-lib.pl';
&can_edit_error("pat");
&ReadParse();
&lock_itsecur_files();

&error_setup($text{'pat_err'});
for($i=0; defined($s = $in{"service_$i"}); $i++) {
	next if (!$s);
	$h = $in{"host_$i"};
	gethostbyname($h) || &error(&text('pat_ehost', $i+1));
	$iface = $in{"iface_$i"};
	$iface eq "" || $iface =~ /^[a-z0-9:\.]+$/ ||
		&error(&text('pat_eiface', $i+1));
	push(@forwards, { 'service' => $s,
			  'host' => $h,
			  'iface' => $iface });
	}

&automatic_backup();
&save_pat(@forwards);
&unlock_itsecur_files();
&remote_webmin_log("update", "pat");
&redirect("");

