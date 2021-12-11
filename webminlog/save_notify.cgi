#!/usr/local/bin/perl
# Save email notification settings

use strict;
use warnings;
require './webminlog-lib.pl';
our (%text, %gconfig, %access, %in, $config_file);
&ReadParse();
&error_setup($text{'notify_err'});
$access{'notify'} || &error($text{'notify_ecannot'});

$gconfig{'webminlog_notify'} = $in{'notify'};
if ($in{'mods_all'}) {
	delete($gconfig{'webminlog_notify_mods'});
	}
else {
	$in{'mods'} || &error($text{'notify_emods'});
	$gconfig{'webminlog_notify_mods'} = join(" ", split(/\0/, $in{'mods'}));
	}
if ($in{'users_all'}) {
	delete($gconfig{'webminlog_notify_users'});
	}
else {
	$in{'users'} || &error($text{'notify_eusers'});
	$gconfig{'webminlog_notify_users'} = join(" ", split(/\0/, $in{'users'}));
	}
!$in{'notify'} || $in{'email'} =~ /\S/ || &error($text{'notify_eemail'});
$gconfig{'webminlog_notify_email'} = $in{'email'};
&lock_file($config_file);
&save_module_config(\%gconfig, "");
&unlock_file($config_file);
&webmin_log("notify");

&redirect("");
