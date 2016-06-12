#!/usr/local/bin/perl
# change_log.cgi
# Enable or disable logging

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'log_err'});

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
$miniserv{'log'} = $in{'log'};
$miniserv{'loghost'} = $in{'loghost'};
$miniserv{'logclf'} = $in{'logclf'};
$miniserv{'logclear'} = $in{'logclear'};
!$in{'logclear'} || $in{'logtime'} =~ /^[1-9][0-9]*$/ ||
	&error(&text('log_ehours', $in{'logtime'}));
$miniserv{'logtime'} = $in{'logtime'};
if ($in{'perms_def'}) {
	delete($miniserv{'logperms'});
	}
else {
	$in{'perms'} =~ /^[0-7]{3,4}$/ || &error($text{'log_eperms'});
	$miniserv{'logperms'} = $in{'perms'};
	}
if (defined($in{'login'})) {
	if ($in{'login'}) {
		# Create and user login wrapper scripts
		&foreign_require("cron");
		&cron::create_wrapper($record_login_cmd,"","record-login.pl");
		&cron::create_wrapper($record_logout_cmd,"","record-logout.pl");
		&cron::create_wrapper($record_failed_cmd,"","record-failed.pl");
		$miniserv{'login_script'} = $record_login_cmd;
		$miniserv{'logout_script'} = $record_logout_cmd;
		$miniserv{'failed_script'} = $record_failed_cmd;
		}
	else {
		# Stop using
		delete($miniserv{'login_script'});
		delete($miniserv{'logout_script'});
		delete($miniserv{'failed_script'});
		}
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

$gconfig{'log'} = $in{'log'};
$gconfig{'logtime'} = $in{'logtime'};
$gconfig{'logclear'} = $in{'logclear'};
$gconfig{'logusers'} =
	$in{'uall'} ? '' : join(" ", split(/\0/, $in{'users'}));
$gconfig{'logmodules'} =
	$in{'mall'} ? '' : join(" ", split(/\0/, $in{'modules'}));
$gconfig{'logfiles'} = $in{'logfiles'};
$gconfig{'logfullfiles'} = $in{'logfullfiles'};
$gconfig{'logperms'} = $miniserv{'logperms'};
!$in{'logfiles'} || &has_command("diff") ||
	&error(&text('log_ediff', "diff"));
$gconfig{'logsyslog'} = $in{'logsyslog'} if (defined($in{'logsyslog'}));
$gconfig{'logemail'} = $in{'email_def'} ? undef : $in{'email'};
$gconfig{'logmodulesemail'} =
	$in{'mallemail'} ? '' : join(" ", split(/\0/, $in{'modulesemail'}));
&lock_file("$config_directory/config");
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&show_restart_page();
&webmin_log("log", undef, undef, \%in);

