#!/usr/local/bin/perl
# save_env.cgi
# Save an existing environment variable, or create a new one

require './cron-lib.pl';
&error_setup($text{'env_err'});
&ReadParse();

@jobs = &list_cron_jobs();
if ($in{'new'}) {
	$job = { };
	}
else {
	$oldjob = $jobs[$in{'idx'}];
	$job->{'file'} = $oldjob->{'file'};
	$job->{'line'} = $oldjob->{'line'};
	}

if ($in{'delete'}) {
	# Just re-direct to delete CGI
	&redirect("delete_env.cgi?idx=$in{'idx'}");
	exit;
	}

# Check if this user is allowed to execute cron jobs
&can_use_cron($in{'user'}) ||
	&error(&text('save_eallow', $in{'user'}));

# Check module access control
&can_edit_user(\%access, $in{'user'}) ||
	&error(&text('save_ecannot', $in{'user'}));

@files = &unique((map { $_->{'file'} } @jobs),
	         "$config{'cron_dir'}/$in{'user'}");
foreach $f (@files) { &lock_file($f); }

# Check and parse inputs
if ($in{'name'} !~ /^\S+$/) {
	&error($text{'save_ename'});
	}
if (!$in{'user'}) {
	&error($text{'save_euser'});
	}
if (!defined(getpwnam($in{'user'}))) {
	&error(&text('save_euser2', $in{'user'}));
	}
$job->{'active'} = $in{'active'};
$job->{'name'} = $in{'name'};
$job->{'value'} = $in{'value'};
$job->{'user'} = $in{'user'};

if (!$in{'new'}) {
	# Editing an existing variable
	&can_edit_user(\%access, $oldjob->{'user'}) ||
		&error(&text('save_ecannot', $oldjob->{'user'}));
	if ($job->{'user'} eq $oldjob->{'user'}) {
		# Not changing user
		if ($in{'where'}) {
			&delete_cron_job($job);
			&insert_cron_job($job);
			}
		else {
			&change_cron_job($job);
			}
		}
	else {
		# Changing user
		&delete_cron_job($oldjob);
		if ($in{'where'}) {
			&insert_cron_job($job);
			}
		else {
			&create_cron_job($job);
			}
		}
	}
else {
	# Creating a new variable
	if ($in{'where'}) {
		&insert_cron_job($job);
		}
	else {
		&create_cron_job($job);
		}
	}

foreach $f (@files) { &unlock_file($f); }
if ($in{'new'}) {
	&webmin_log("create", "env", $in{'user'}, \%in);
	}
else {
	&webmin_log("modify", "env", $in{'user'}, \%in);
	}
&redirect("");


