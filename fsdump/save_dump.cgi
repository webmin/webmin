#!/usr/local/bin/perl
# save_dump.cgi
# Save the details of a scheduled backup

require './fsdump-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'save_err'});

# Create wrapper for ftp transfer script
&cron::create_wrapper($ftp_cmd, $module_name, "ftp.pl");

if ($in{'id'}) {
	$dump = &get_dump($in{'id'});
	$access{'edit'} && &can_edit_dir($dump) ||
		&error($text{'dump_ecannot2'});
	@jobs = &foreign_call("cron", "list_cron_jobs");
	foreach $j (@jobs) {
		$job = $j if ($j->{'command'} eq "$cron_cmd $dump->{'id'}");
		}
	$oldenabled = $dump->{'enabled'};
	}
else {
	$access{'edit'} || &error($text{'dump_ecannot1'});
	}

if ($in{'delete'}) {
	# Just delete this dump
	&delete_dump($dump);
	if ($job) {
		&lock_file($job->{'file'});
		&foreign_call("cron", "delete_cron_job", $job);
		&unlock_file($job->{'file'});
		}
	delete($dump->{'pass'});
	&webmin_log("delete", undef, $dump->{'id'}, $dump);
	&redirect("");
	}
elsif ($in{'restore'}) {
	# Redirect to restore form
	&redirect("restore_form.cgi?fs=$dump->{'fs'}&id=$in{'id'}");
	}
elsif ($in{'clone'}) {
	# Redirect to create form, but in clone mode
	&redirect("edit_dump.cgi?id=$in{'id'}&clone=1");
	}
else {
	# Validate and store inputs
	if (&multiple_directory_support($in{'fs'})) {
		$in{'dir'} =~ s/[\r\n]+/\t/g;
		foreach $d (split(/\t+/, &date_subs($in{'dir'}))) {
			-d $d || &error($text{'save_edir'});
			if ($in{'fs'} ne 'tar') {
				$fs = &directory_filesystem($d);
				&same_filesystem($fs, $in{'fs'}) ||
					&error($text{'save_efs'});
				}
			&can_edit_dir($d) || &error($text{'dump_ecannot3'});
			}
		$in{'dir'} || &error($text{'save_edir'});
		$dump->{'tabs'} = 1;	# tab used to split dirs
		}
	else {
		$d = &date_subs($in{'dir'});
		-d $d || &error($text{'save_edir'});
		if ($in{'fs'} ne 'tar') {
			$fs = &directory_filesystem($d);
			&same_filesystem($fs, $in{'fs'}) ||
				&error($text{'save_efs'});
			}
		&can_edit_dir($d) || &error($text{'dump_ecannot3'});
		}
	$dump->{'dir'} = $in{'dir'};
	$dump->{'fs'} = $in{'fs'};
	$dump->{'email'} = $in{'email'};
	$dump->{'subject'} = $in{'subject_def'} ? undef : $in{'subject'};
	if ($access{'extra'}) {
		$dump->{'extra'} = $in{'extra'};
		}
	if ($access{'cmds'}) {
		$dump->{'before'} = $in{'before'};
		$dump->{'after'} = $in{'after'};
		$dump->{'beforefok'} = !$in{'beforefok'};
		$dump->{'afterfok'} = !$in{'afterfok'};
		$dump->{'afteraok'} = !$in{'afteraok'};
		}
	$in{'file'} =~ s/^\s+//; $in{'file'} =~ s/\s+$//;
	$in{'hfile'} =~ s/^\s+//; $in{'hfile'} =~ s/\s+$//;
	&parse_dump($dump);
	$dump->{'reverify'} = $in{'reverify'} if (defined(&verify_dump));
	$dump->{'enabled'} = $in{'enabled'};
	$dump->{'follow'} = $in{'enabled'} == 2 ? $in{'follow'} : undef;
	&foreign_call("cron", "parse_times_input", $dump, \%in);

	# Create or update the dump and cron job
	&lock_file($cron_cmd);
	&cron::create_wrapper($cron_cmd, $module_name, "backup.pl");
	&unlock_file($cron_cmd);
	&save_dump($dump);
	local $oldjob = $job;
	if ($dump->{'enabled'} == 1) {
		# Create cron job and script
		$job->{'user'} = 'root';
		$job->{'active'} = 1;
		$job->{'special'} = $dump->{'special'};
		$job->{'mins'} = $dump->{'mins'};
		$job->{'hours'} = $dump->{'hours'};
		$job->{'days'} = $dump->{'days'};
		$job->{'months'} = $dump->{'months'};
		$job->{'weekdays'} = $dump->{'weekdays'};
		$job->{'command'} = "$cron_cmd $dump->{'id'}";
		}
	&lock_file(&cron::cron_file($job)) if ($job);
	if ($dump->{'enabled'} == 1 && !$oldjob) {
		# Create the cron job
		&foreign_call("cron", "create_cron_job", $job); 
		}
	elsif ($dump->{'enabled'} == 1 && $oldjob) {
		# Update the cron job
		&foreign_call("cron", "change_cron_job", $job); 
		}
	elsif ($dump->{'enabled'} != 1 && $oldjob) {
		# Delete the cron job
		&foreign_call("cron", "delete_cron_job", $job);
		}
	&unlock_file(&cron::cron_file($job)) if ($job);

	delete($dump->{'pass'});
	&webmin_log($in{'id'} ? "modify" : "create", undef,
		    $dump->{'id'}, $dump);
	if ($in{'savenow'}) {
		&redirect("backup.cgi?id=$dump->{'id'}");
		}
	else {
		&redirect("");
		}
	}

