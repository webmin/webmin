#!/usr/local/bin/perl
# save_sched.cgi
# Save scheduled monitoring options

require './status-lib.pl';
$access{'sched'} || &error($text{'sched_ecannot'});
&ReadParse();
&error_setup($text{'sched_err'});

# Parse and save inputs
$in{'email_def'} || $in{'email'} =~ /\S/ || &error($text{'sched_eemail'});
$config{'sched_email'} = $in{'email_def'} ? '' : $in{'email'};
if ($config{'pager_cmd'}) {
	$config{'sched_pager'} = $in{'pager_def'} ? '' : $in{'pager'};
	}
if ($in{'sms_def'}) {
	delete($config{'sched_carrier'});
	delete($config{'sched_sms'});
	}
else {
	$config{'sched_carrier'} = $in{'carrier'};
	($carrier) = grep { $_->{'id'} eq $in{'carrier'} }
			  &list_sms_carriers();
	if ($carrier->{'alpha'}) {
		$in{'sms'} =~ /^\S+$/ || &error($text{'sched_esmsname'});
		}
	else {
		$in{'sms'} =~ /^\d+$/ || &error($text{'sched_esmsnumber'});
		}
	$config{'sched_sms'} = $in{'sms'};
	}
if ($in{'smode'} == 0) {
	delete($config{'sched_subject'});
	}
elsif ($in{'smode'} == 1) {
	$config{'sched_subject'} = '*';
	}
else {
	$in{'subject'} =~ /\S/ || &error($text{'sched_esubject'});
	$config{'sched_subject'} = $in{'subject'};
	}
if ($in{'from_def'}) {
	delete($config{'sched_from'});
	}
else {
	$in{'from'} =~ /^\S+$/ || &error($text{'sched_efrom'});
	$config{'sched_from'} = $in{'from'};
	}
if ($in{'smtp_def'}) {
	if (!$in{'from_def'}) {
		&foreign_require("mailboxes");
		$err = &mailboxes::test_mail_system();
		$err && &error(&text('sched_eemailserver', $err));
		}
	delete($config{'sched_smtp'});
	}
else {
	if (!$in{'from_def'}) {
		&to_ipaddress($in{'smtp'}) || &to_ip6address($in{'smtp'}) ||
			&error($text{'sched_esmtp'});
		}
	$config{'sched_smtp'} = $in{'smtp'};
	}
$config{'sched_mode'} = $in{'mode'};
$in{'int'} =~ /^\d+$/ || &error($text{'sched_eint'});
$config{'sched_int'} = $in{'int'};
$config{'sched_period'} = $in{'period'};
$in{'offset'} =~ /^\d+$/ || &error($text{'sched_eoffset'});
$config{'sched_offset'} = $in{'offset'};
$config{'sched_warn'} = $in{'warn'};
$config{'sched_single'} = $in{'single'};
@hours = split(/\0/, $in{'hours'});
@hours || &error($text{'sched_ehours'});
$config{'sched_hours'} = @hours == 24 ? '' : join(" ", @hours);
@days = split(/\0/, $in{'days'});
@days || &error($text{'sched_edays'});
$config{'sched_days'} = @days == 7 ? '' : join(" ", @days);
&lock_file("$module_config_directory/config");
&save_module_config();
&unlock_file("$module_config_directory/config");

# Setup or remove the cron job
&setup_cron_job();

&webmin_log("sched");
&redirect("");


