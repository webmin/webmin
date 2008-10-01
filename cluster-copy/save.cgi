#!/usr/local/bin/perl
# Save, delete or create a scheduled copy

require './cluster-copy-lib.pl';
&error_setup($text{'save_err'});
&ReadParse();

if (!$in{'new'}) {
	$copy = &get_copy($in{'id'});
	$job = &find_cron_job($copy);
	}

if ($in{'run'}) {
	# Run the job now
	&redirect("exec.cgi?id=$in{'id'}");
	exit;
	}
elsif ($in{'delete'}) {
	# Just delete it
	&delete_copy($copy);
	if ($job) {
		&lock_file(&cron::cron_file($job));
		&cron::delete_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}
	}
else {
	# Check and parse inputs
	$in{'files'} =~ s/\r//g;
	@files = split(/\n/, $in{'files'});
	foreach $f (@files) {
		$f =~ /^\// || &error(&text('save_efile', $f));
		}
	$copy->{'files'} = join("\t", @files);
	@files || &error($text{'save_efiles'});
	$in{'dest'} =~ /^\// || &error($text{'save_edest'});
	if ($in{'email_def'}) {
		$copy->{'email'} = '';
		}
	else {
		$in{'email'} =~ /^\S+$/ || &error($text{'save_eemail'});
		$copy->{'email'} = $in{'email'};
		}
	$copy->{'dest'} = $in{'dest'};
	$copy->{'dmode'} = $in{'dmode'};
	$copy->{'before'} = $in{'before'};
	$copy->{'cmd'} = $in{'cmd'};
	$copy->{'beforelocal'} = !$in{'beforeremote'};
	$copy->{'cmdlocal'} = !$in{'cmdremote'};
	@servers = split(/\0/, $in{'servers'});
	@servers || &error($text{'save_eservers'});
	$copy->{'servers'} = join(" ", @servers);
	$copy->{'sched'} = $in{'sched'};
	&cron::parse_times_input($copy, \%in);

	# Save or create
	&save_copy($copy);
	if ($job) {
		&lock_file(&cron::cron_file($job));
		&cron::delete_cron_job($job);
		}
	if ($in{'sched'}) {
		&cron::create_wrapper($cron_cmd, $module_name, "copy.pl");
		$job = { 'user' => 'root',
			 'command' => "$cron_cmd $copy->{'id'}",
			 'active' => 1,
			 'mins' => $copy->{'mins'},
			 'hours' => $copy->{'hours'},
			 'days' => $copy->{'days'},
			 'months' => $copy->{'months'},
			 'weekdays' => $copy->{'weekdays'},
			 'special' => $copy->{'special'} };
		&lock_file(&cron::cron_file($job));
		&cron::create_cron_job($job);
		}
	&unlock_file(&cron::cron_file($job)) if ($job);
	}
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'copy', undef, $copy);
&redirect("");


