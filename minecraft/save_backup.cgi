#!/usr/local/bin/perl
# Enable or disable scheduled backups

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
&foreign_require("webmincron");
our (%in, %text, %config, $module_config_file, $module_name);
&ReadParse();
&error_setup($text{'backup_err'});

my $job = &get_backup_job();
if (!$in{'enabled'}) {
	# Delete scheduled job, if any
	if ($job) {
		&webmincron::delete_webmin_cron($job);
		}
	&webmin_log("disable", "backup");
	&redirect("");
	}
else {
	# Validate inputs
	&has_command("zip") || &error($text{'backup_ezip'});
	$job ||= { 'module' => $module_name,
		   'func' => 'backup_worlds' };
	&webmincron::parse_times_input($job, \%in);
	$in{'dir'} =~ /^\// || &error($text{'backup_edir'});
	$config{'backup_dir'} = $in{'dir'};
	if ($in{'worlds_def'}) {
		$config{'backup_worlds'} = '';
		}
	else {
		$in{'worlds'} || &error($text{'backup_eworlds'});
		$config{'backup_worlds'} =
			join(' ', split(/\0/, $in{'worlds'}));
		}
	if ($in{'email_def'}) {
		$config{'backup_email'} = '';
		}
	else {
		$in{'email'} =~ /^\S+\@\S+$/ || &error($text{'backup_eemail'});
		$config{'backup_email'} = $in{'email'};
		$config{'backup_email_err'} = $in{'email_err'};
		}
	&lock_file($module_config_file);
	&save_module_config();
	&unlock_file($module_config_file);
	&webmincron::save_webmin_cron($job);
	&webmin_log("enable", "backup", $in{'backup_dir'});

	# Backup now if selected
	if ($in{'now'}) {
		&ui_print_unbuffered_header(undef, $text{'backup_title'}, "");

		print $text{'backup_doing'},"<p>\n";
		my ($out, $failed) = &execute_backup_worlds();
		foreach my $o (@$out) {
			print $o,"<br>\n";
			}
		if ($failed) {
			print $text{'backup_failed'},"<p>\n";
			}
		else {
			print $text{'backup_done'},"<p>\n";
			}

		&ui_print_footer("", $text{'index_return'});
		}
	else {
		&redirect("");
		}
	}
