#!/usr/local/bin/perl
# Save Usermin webserver logging options

require './usermin-lib.pl';
&ReadParse();
$access{'log'} || &error($text{'acl_ecannot'});
&error_setup($text{'log_err'});
&get_usermin_miniserv_config(\%miniserv);

# Only a change of error destination needs the systemd drop-in and restart.
my $journal_changed = defined($in{'error_journal'}) &&
	($miniserv{'errorlog'} eq '-' ? 1 : 0) != ($in{'error_journal'} ? 1 : 0);

# Validate and save the access-log settings.
!$in{'logclear'} || $in{'logtime'} =~ /^[1-9][0-9]*$/ ||
	&error(&text('log_ehours', $in{'logtime'}));
$miniserv{'log'} = $in{'log'};
$miniserv{'loghost'} = $in{'loghost'};
$miniserv{'logtrust'} = $in{'logtrust'};
$miniserv{'logclf'} = $in{'logclf'};
$miniserv{'logclear'} = $in{'logclear'};
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

# Restart through systemd when stderr needs to be re-attached.
if ($journal_changed) {
	&webmin::restart_miniserv_systemd_service("usermin.service", 2);
	}
else {
	&restart_usermin_miniserv();
	}

&webmin_log("log");
&redirect("");
