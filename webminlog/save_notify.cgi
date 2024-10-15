#!/usr/local/bin/perl
# Save email notification settings

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './webminlog-lib.pl';
our (%text, %gconfig, %access, %in, $config_file);
&ReadParse();
&error_setup($text{'notify_err'});
$access{'notify'} || &error($text{'notify_ecannot'});

if ($in{'notify'}) {
	$in{'email'} =~ /\S/ || &error($text{'notify_eemail'});
	$gconfig{'logemail'} = $in{'email_def'} ? "*" : $in{'email'};
	}
else {
	delete($gconfig{'logemail'});
	}
if ($in{'mods_all'}) {
	delete($gconfig{'logmodulesemail'});
	}
else {
	$in{'mods'} || &error($text{'notify_emods'});
	$gconfig{'logmodulesemail'} = join(" ", split(/\0/, $in{'mods'}));
	}
if ($in{'users_all'}) {
	delete($gconfig{'logusersemail'});
	}
else {
	$in{'users'} || &error($text{'notify_eusers'});
	$gconfig{'logusersemail'} = join(" ", split(/\0/, $in{'users'}));
	}
$gconfig{'logemailusub'} = $in{'usub'};
$gconfig{'logemailmsub'} = $in{'msub'};
&lock_file($config_file);
&save_module_config(\%gconfig, "");
&unlock_file($config_file);
&webmin_log("notify");

&redirect("");
