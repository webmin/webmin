#!/usr/local/bin/perl
# Save Usermin webserver logging options

require './usermin-lib.pl';
&ReadParse();
$access{'log'} || &error($text{'acl_ecannot'});
&error_setup($text{'log_err'});
&get_usermin_miniserv_config(\%miniserv);

# Only a change of error destination on a systemd-managed service needs the
# drop-in and a full restart; otherwise the option is ignored.
my $journal_changed = defined($in{'error_journal'}) &&
	&webmin::miniserv_systemd_journal_available("usermin.service") &&
	($miniserv{'errorlog'} eq '-' ? 1 : 0) != ($in{'error_journal'} ? 1 : 0);

# Either Miniserv clears the logs itself, or logrotate takes them over. There
# is no setting for the latter, so it is on when clearing is off and a section
# already rotates the logs.
my $logrotate = $in{'logclear'} == 2 ? 1 : 0;
!$logrotate || &webmin::miniserv_logrotate_available() ||
	&error($text{'log_elogrotate'});
my $was_logrotate = !int($miniserv{'logclear'}) &&
		    &webmin::miniserv_logrotate_available() &&
		    &webmin::get_miniserv_logrotate_section(\%miniserv) ? 1 : 0;

# Validate and save the access-log settings.
$miniserv{'log'} = $in{'log'};
$miniserv{'loghost'} = $in{'loghost'};
$miniserv{'logtrust'} = $in{'logtrust'};
$miniserv{'logclf'} = $in{'logclf'};
$miniserv{'logclear'} = $logrotate ? 0 : $in{'logclear'};
!$miniserv{'logclear'} || $in{'logtime'} =~ /^[1-9][0-9]*$/ ||
	&error(&text('log_ehours', $in{'logtime'}));
$miniserv{'logtime'} = $in{'logtime'};

# Save the error destination and matching systemd drop-in when supported.
&lock_file($usermin_miniserv_config);
if ($journal_changed) {
	&webmin::set_miniserv_error_destination(\%miniserv,
		$usermin_miniserv_config, "usermin.service",
		$in{'error_journal'});
	}
else {
	&put_usermin_miniserv_config(\%miniserv);
	}
&unlock_file($usermin_miniserv_config);

# Hand the Miniserv logs to logrotate, or take them back from it
if ($logrotate) {
	&webmin::setup_miniserv_logrotate(\%miniserv, "usermin");
	}
elsif ($was_logrotate) {
	&webmin::remove_miniserv_logrotate(\%miniserv);
	}

# Restart through systemd when stderr needs to be re-attached.
if ($journal_changed) {
	&webmin::restart_miniserv_systemd_service("usermin.service", 2);
	}
else {
	&restart_usermin_miniserv();
	}

&webmin_log("log");
&redirect("");
