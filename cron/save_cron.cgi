#!/usr/local/bin/perl
# save_cron.cgi
# Save an existing cron job, or create a new one

require './cron-lib.pl';
&error_setup($text{'save_err'});
&ReadParse();

@jobs = &list_cron_jobs();
if ($in{'new'}) {
	$access{'create'} || &error($text{'save_ecannot2'});
	$job = { 'type' => 0 };
	}
else {
	$oldjob = $jobs[$in{'idx'}];
	$job->{'type'} = $oldjob->{'type'};
	$job->{'file'} = $oldjob->{'file'};
	$job->{'line'} = $oldjob->{'line'};
	$job->{'nolog'} = $oldjob->{'nolog'};
	}

# Check if this user is allowed to execute cron jobs
if (&supports_users()) {
	&can_use_cron($in{'user'}) ||
		&error(&text('save_eallow', &html_escape($in{'user'})));
	}

# Check module access control
&can_edit_user(\%access, $in{'user'}) ||
	&error(&text('save_ecannot', &html_escape($in{'user'})));

@files = &unique((map { $_->{'file'} } @jobs),
	         "$config{'cron_dir'}/$in{'user'}");
foreach $f (@files) { &lock_file($f); }

# Check and parse inputs
if ($in{"cmd"} !~ /\S/ && $access{'command'}) {
	&error($text{'save_ecmd'});
	}
if (&supports_users()) {
	if (!$in{'user'}) {
		&error($text{'save_euser'});
		}
	if (!defined(getpwnam($in{'user'}))) {
		&error(&text('save_euser2', &html_escape($in{'user'})));
		}
	}
&parse_times_input($job, \%in);
$in{input} =~ s/\r//g; $in{input} =~ s/%/\\%/g;
$in{cmd} =~ s/%/\\%/g;
$job->{'active'} = $in{'active'};
if ($access{'command'}) {
	$job->{'command'} = $in{'cmd'};
	if ($in{input} =~ /\S/) {
		@inlines = split(/\n/ , $in{input});
		$job->{'command'} .= '%'.join('%' , @inlines);
		}
	}
else {
	$job->{'command'} = $oldjob->{'command'};
	}

if (&supports_users()) {
	$job->{'user'} = $in{'user'};
	}

if (defined($in{'range_def'})) {
	# Save range to run
	&parse_range_input($job, \%in);
	&unconvert_range($job);
	}

$job->{'comment'} = $in{'comment'};
&unconvert_comment($job);

if (!$in{'new'}) {
	# Editing an existing job
	&can_edit_user(\%access, $oldjob->{'user'}) ||
		&error(&text('save_ecannot', $oldjob->{'user'}));
	if ($job->{'user'} eq $oldjob->{'user'}) {
		&change_cron_job($job);
		}
	else {
		&delete_cron_job($oldjob);
		&create_cron_job($job);

		# Find new index, which will change due to user move
		undef(@cron_jobs_cache);
		$in{'idx'} = undef;
		foreach $newjob (&list_cron_jobs()) {
			if ($newjob->{'user'} eq $job->{'user'} &&
			    $newjob->{'active'} eq $job->{'active'} &&
			    $newjob->{'command'} eq $job->{'command'}) {
				$in{'idx'} = $newjob->{'index'};
				}
			}
		}
	}
else {
	# Creating a new job
	&create_cron_job($job);
	}

foreach $f (@files) { &unlock_file($f); }
if ($in{'new'}) {
	&webmin_log("create", "cron", $in{'user'}, \%in);
	}
else {
	&webmin_log("modify", "cron", $in{'user'}, \%in);
	}

if ($in{'saverun'}) {
	# Redirect to execute form
	defined($in{'idx'}) || &error($text{'save_eidx'});
	&redirect("exec_cron.cgi?idx=$in{'idx'}");
	}
else {
	# Just go back to main menu
	&redirect("index.cgi?search=".&urlize($in{'search'}));
	}


