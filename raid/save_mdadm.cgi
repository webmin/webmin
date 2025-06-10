#!/usr/local/bin/perl
# Update mdadm.conf with notification settings

require './raid-lib.pl';
&ReadParse();
&error_setup($text{'notif_err'});

# Validate inputs
$notif = { };
if (!$in{'mailaddr_def'}) {
	$in{'mailaddr'} =~ /^\S+\@\S+$/ || &error($text{'notif_emailaddr'});
	$notif->{'MAILADDR'} = $in{'mailaddr'};
	}
else {
	$notif->{'MAILADDR'} = undef;
	}
if (!$in{'mailfrom_def'}) {
	$in{'mailfrom'} =~ /^\S+\@\S+$/ || &error($text{'notif_emailfrom'});
	$notif->{'MAILFROM'} = $in{'mailfrom'};
	}
else {
	$notif->{'MAILFROM'} = undef;
	}
if (!$in{'program_def'}) {
	-x $in{'program'} || &error($text{'notif_eprogram'});
	$notif->{'PROGRAM'} = $in{'program'};
	}
else {
	$notif->{'PROGRAM'} = undef;
	}

# Save them
&lock_file($config{'mdadm'});
&save_mdadm_notifications($notif);
&unlock_file($config{'mdadm'});

# Enable/disable
if (&get_mdadm_action()) {
	&save_mdadm_monitoring($in{'monitor'});
	}

&webmin_log("notif");

&redirect("");

