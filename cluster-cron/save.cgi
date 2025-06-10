#!/usr/local/bin/perl
# save.cgi
# Save an existing cluster cron job, or create a new one

require './cluster-cron-lib.pl';
&error_setup($text{'save_err'});
&ReadParse();

if ($in{'exec'}) {
	&redirect("exec.cgi?id=".&urlize($in{'id'}));
	return;
	}
elsif ($in{'delete'}) {
	&redirect("delete.cgi?id=".&urlize($in{'id'}));
	return;
	}

@jobs = &list_cluster_jobs();
if ($in{'new'}) {
	$job = { 'type' => 0,
		 'cluster_id' => time()."-".$$ };
	}
else {
	($oldjob) = grep { $_->{'cluster_id'} eq $in{'id'} } @jobs;
	$job->{'cluster_id'} = $oldjob->{'cluster_id'};
	$job->{'type'} = $oldjob->{'type'};
	$job->{'file'} = $oldjob->{'file'};
	$job->{'line'} = $oldjob->{'line'};
	$job->{'nolog'} = $oldjob->{'nolog'};
	}

# Check and parse inputs
if ($in{"cmd"} !~ /\S/) {
	&error($cron::text{'save_ecmd'});
	}
if (!$in{'user'}) {
	&error($cron::text{'save_euser'});
	}
&cron::parse_times_input($job, \%in);
$in{input} =~ s/\r//g; $in{input} =~ s/%/\\%/g;
$in{cmd} =~ s/%/\\%/g;
$job->{'active'} = $in{'active'};
$job->{'cluster_command'} = $in{'cmd'};
if ($in{input} =~ /\S/) {
	@inlines = split(/\n/ , $in{input});
	$job->{'cluster_input'} .= join('%' , @inlines);
	}
$job->{'command'} = "$cluster_cron_cmd $job->{'cluster_id'}";
$job->{'cluster_user'} = $in{'user'};
$job->{'user'} = 'root';
$job->{'cluster_server'} = join(" ", split(/\0/, $in{'server'}));

# Make sure the wrapper script exists
if (!-r $cluster_cron_cmd) {
	&lock_file($cluster_cron_cmd);
	&cron::create_wrapper($cluster_cron_cmd, $module_name, "cron.pl");
	&unlock_file($cluster_cron_cmd);
	}

if (!$in{'new'}) {
	# Editing an existing job
	&modify_cluster_job($job);
	}
else {
	# Creating a new job
	&create_cluster_job($job);
	}

if ($in{'new'}) {
	&webmin_log("create", "cron", $job->{'cluster_user'}, $job);
	}
else {
	&webmin_log("modify", "cron", $job->{'cluster_user'}, $job);
	}
&redirect("");


