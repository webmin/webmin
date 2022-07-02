#!/usr/local/bin/perl
# save_log.cgi
# Save, create or delete options for a log file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %gconfig, %access, $module_name, %in, $remote_user,
     $cron_cmd, $custom_logs_file);
require './webalizer-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'save_err'});
$access{'view'} && &error($text{'edit_ecannot'});
!$in{'new'} || $access{'add'} || &error($text{'edit_ecannot'});
&can_edit_log($in{'file'}) || &error($text{'edit_efilecannot'});

# Find the cron job
my $job;
if (!$in{'new'} && !$in{'view'} && !$in{'run'}) {
	my @jobs = &cron::list_cron_jobs();
	foreach my $j (@jobs) {
		$job = $j if ($j->{'command'} eq "$cron_cmd $in{'file'}");
		}
	}

if ($in{'view'}) {
	# Re-direct to the view page
	&redirect("view_log.cgi/".&urlize(&urlize($in{'file'}))."/index.html");
	exit;
	}
elsif ($in{'global'}) {
	# Re-direct to the options page
	&redirect("edit_global.cgi?file=".&urlize($in{'file'})."&type=$in{'type'}&custom=$in{'custom'}");
	exit;
	}
elsif ($in{'run'}) {
	# Force report generation and show the output
	&ui_print_unbuffered_header(undef, $text{'gen_title'}, "");

	my $lconf = &get_log_config($in{'file'});
	print "<b>",&text('gen_header', "<tt>$in{'file'}</tt>"),"</b><br>\n";
	print "<pre>";
	my $rv = &generate_report($in{'file'}, \*STDOUT, 1);
	print "</pre>\n";
	if ($rv && -r "$lconf->{'dir'}/index.html") {
		print "<b>$text{'gen_done'}</b><p>\n";
		print &ui_link("view_log.cgi/".&urlize(&urlize($in{'file'})).
			       "/index.html", $text{'gen_view'})."<p>\n";
		}
	elsif ($rv) {
		print "<b>$text{'gen_nothing'}</b><p>\n";
		}
	else {
		print "<b>$text{'gen_failed'}</b><p>\n";
		}

	&webmin_log("generate", "log", $in{'file'});
	&ui_print_footer("edit_log.cgi?file=".&urlize($in{'file'}).
	        "&type=$in{'type'}&custom=$in{'custom'}", $text{'edit_return'},
		"", $text{'index_return'});
	exit;
	}
elsif ($in{'delete'}) {
	# Delete this custom log file from the configuration
	&lock_file($custom_logs_file);
	my @custom = &read_custom_logs();
	@custom = grep { $_->{'file'} ne $in{'file'} } @custom;
	if ($job) {
		&lock_file($job->{'file'});
		&foreign_call("cron", "delete_cron_job", $job);
		&unlock_file($job->{'file'});
		}
	&write_custom_logs(@custom);
	&unlock_file($custom_logs_file);
	my $cfile = &log_config_name($in{'file'});
	&unlink_logged($cfile);
	&webmin_log("delete", "log", $in{'file'});
	}
else {
	# Validate and store inputs
	if ($in{'new'}) {
		-r $in{'file'} && !-d $in{'file'} ||
			&error($text{'save_efile'});
		}
	-d $in{'dir'} || &error($text{'save_edir'});
	$in{'cmode'} != 2 || -r $in{'cfile'} || &error($text{'save_ecfile'});
	my $lconf = { };
	if ($access{'user'} eq '*') {
		# Set the user to whatever was entered
		defined(getpwnam($in{'user'})) || &error($text{'save_euser'});
		$lconf->{'user'} = $in{'user'};
		}
	elsif (!$in{'new'} && $lconf->{'dir'}) {
		# This is not a new log, so the user cannot be changed
		}
	elsif ($access{'user'} eq '') {
		# This is a new log, or one that has not been saved for
		# the first time yet. Use the webmin user as the user
		defined(getpwnam($remote_user)) ||
			&error(&text('save_ewuser', $remote_user));
		$lconf->{'user'} = $remote_user;
		}
	else {
		# This is a new log, or one that has not been saved for
		# the first time yet. Use the user set in the ACL
		$lconf->{'user'} = $access{'user'};
		}
	$lconf->{'dir'} = $in{'dir'};
	$lconf->{'sched'} = $in{'sched'};
	$lconf->{'type'} = $in{'type'};
	$lconf->{'over'} = $in{'over'};
	$lconf->{'clear'} = $in{'clear'};
	&cron::parse_times_input($lconf, \%in);

	# Create or delete the cron job
	my $oldjob = $job;
	if ($lconf->{'sched'}) {
		# Create cron job and script
		$job->{'user'} = 'root';
		$job->{'active'} = 1;
		$job->{'command'} = "$cron_cmd $in{'file'}";
		&lconf_to_cron($lconf, $job);
		&lock_file($cron_cmd);
		&cron::create_wrapper($cron_cmd, $module_name, "webalizer.pl");
		&unlock_file($cron_cmd);
		}
	&lock_file(&cron::cron_file($job)) if ($job);
	if ($lconf->{'sched'} && !$oldjob) {
		# Create the cron job
		&foreign_call("cron", "create_cron_job", $job); 
		}
	elsif ($lconf->{'sched'} && $oldjob) {
		# Update the cron job
		&foreign_call("cron", "change_cron_job", $job); 
		}
	elsif (!$lconf->{'sched'} && $oldjob) {
		# Delete the cron job
		&foreign_call("cron", "delete_cron_job", $job);
		}
	&unlock_file(&cron::cron_file($job)) if ($job);

	if ($in{'new'}) {
		# Add a new custom log file to the configuration
		&lock_file($custom_logs_file);
		my @custom = &read_custom_logs();
		push(@custom, { 'file' => $in{'file'}, 'type' => $in{'type'} });
		&write_custom_logs(@custom);
		&unlock_file($custom_logs_file);
		}

	# Create or link the custom webalizer.conf file
	my $cfile = &config_file_name($in{'file'});
	if ($in{'cmode'} == 0) {
		# None at all
		&unlink_logged($cfile);
		}
	elsif ($in{'cmode'} == 1) {
		# File under /etc/webmin/webalizer
		if (-l $cfile) {
			&unlink_logged($cfile);
			}
		if (!-r $cfile) {
			# Need to copy into place
			&copy_source_dest($config{'webalizer_conf'}, $cfile);
			}
		}
	elsif ($in{'cmode'} == 2) {
		# Symbolic link to somewhere
		&unlink_logged($cfile);
		symlink($in{'cfile'}, $cfile);
		}

	# Update the log file's options
	$cfile = &log_config_name($in{'file'});
	&lock_file($cfile);
	&save_log_config($in{'file'}, $lconf);
	&unlock_file($cfile);
	&webmin_log($in{'new'} ? "create" : "modify", "log", $in{'file'});
	}
&redirect("");

