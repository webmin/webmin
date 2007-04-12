#!/usr/local/bin/perl
# save_logcheck.cgi
# Save logcheck.sh options

require './sentry-lib.pl';
&ReadParse();
&error_setup($text{'logcheck_err'});

# Get the current cron job
&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
foreach $j (@jobs) {
	$job = $j if ($j->{'command'} =~ /$config{'logcheck'}/);
	}

# Validate and save inputs
$conf = &get_logcheck_config();
&lock_config_files($conf);
$in{'to'} =~ /^\S+$/ || &error($text{'logcheck_eto'});
if ($in{'runparts'}) {
	# Being run from a script that we cannot change
	}
elsif (!$in{'active'} && !$job) {
	# Cron job is not setup yet, and doesn't need to be .. do nothing
	}
else {
	# Create or update the cron job
	if (!$job) {
		$job = { 'command' => $config{'logcheck'},
			 'user' => 'root' };
		$creating++;
		}
	$job->{'active'} = $in{'active'};
	&cron::parse_times_input($job, \%in);
	&lock_file(&cron::cron_file($job));
	if ($creating) {
		&cron::create_cron_job($job);
		}
	else {
		&cron::change_cron_job($job);
		}
	&unlock_file(&cron::cron_file($job));
	}
$to = &find_value("SYSADMIN", $conf);
if ($to =~ /^\$(\S+)$/) {
	&save_config($conf, $1, $in{'to'});
	}
else {
	&save_config($conf, "SYSADMIN", $in{'to'});
	}
&flush_file_lines();
&unlock_config_files($conf);

$hacking = &find_value("HACKING_FILE", $conf, 1);
$hacking = &find_value("CRACKING_FILE", $conf, 1) if (!$hacking);
&lock_file($hacking);
$in{'hacking'} =~ s/\r//g;
$in{'hacking'} =~ s/\n*$/\n/;
&open_tempfile(HACKING, ">$hacking");
&print_tempfile(HACKING, $in{'hacking'});
&close_tempfile(HACKING);
&unlock_file($hacking);

$violations = &find_value("VIOLATIONS_FILE", $conf, 1);
&lock_file($violations);
$in{'violations'} =~ s/\r//g;
$in{'violations'} =~ s/\n*$/\n/;
&open_tempfile(VIOLATIONS, ">$violations");
&print_tempfile(VIOLATIONS, $in{'violations'});
&close_tempfile(VIOLATIONS);
&unlock_file($violations);

$violations_ign = &find_value("VIOLATIONS_IGNORE_FILE", $conf, 1);
&lock_file($violations_ign);
$in{'violations_ign'} =~ s/\r//g;
$in{'violations_ign'} =~ s/\n*$/\n/;
&open_tempfile(IGNORE, ">$violations_ign");
&print_tempfile(IGNORE, $in{'violations_ign'});
&close_tempfile(IGNORE);
&unlock_file($violations_ign);

$ignore = &find_value("IGNORE_FILE", $conf, 1);
&lock_file($ignore);
$in{'ignore'} =~ s/\r//g;
$in{'ignore'} =~ s/\n*$/\n/;
&open_tempfile(IGNORE, ">$ignore");
&print_tempfile(IGNORE, $in{'ignore'});
&close_tempfile(IGNORE);
&unlock_file($ignore);

&webmin_log("logcheck");
&redirect("");

