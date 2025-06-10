#!/usr/local/bin/perl
# Execute multiple backup jobs, one for each client

require './bacula-backup-lib.pl';
&ui_print_unbuffered_header(undef,  $text{'gbackup_title'}, "");
&ReadParse();

# Get the backup job def and real jobs
$conf = &get_director_config();
@jobdefs = &find("JobDefs", $conf);
$jobdef = &find_by("Name", "ocjob_".$in{'job'}, \@jobdefs);
foreach $job (&get_bacula_jobs()) {
	($j, $c) = &is_oc_object($job);
	if ($j eq $in{'job'} && $c) {
		push(@jobs, $job);
		}
	}

print "<b>",&text('gbackup_run', "<tt>$in{'job'}</tt>",
				 scalar(@jobs)),"</b>\n";

# Clear messages
$h = &open_console();
&console_cmd($h, "messages");

# Run the real jobs
print "<dl>\n";
foreach $job (@jobs) {
	($j, $c) = &is_oc_object($job);
	print "<dt>",&text('gbackup_on', "<tt>$c</tt>"),"\n"; 
	print "<dd><pre>";

	# Select the job to run
	&sysprint($h->{'infh'}, "run\n");
	&wait_for($h->{'outfh'}, 'run\\n');
	$rv = &wait_for($h->{'outfh'}, 'Select Job.*:');
	print $wait_for_input;
	if ($rv == 0 && $wait_for_input =~ /(\d+):\s+\Q$job->{'name'}\E/) {
		&sysprint($h->{'infh'}, "$1\n");
		}
	else {
		&job_error($text{'backup_ejob'});
		}

	# Say that it is OK
	$rv = &wait_for($h->{'outfh'}, 'OK to run.*:');
	print $wait_for_input;
	if ($rv == 0) {
		&sysprint($h->{'infh'}, "yes\n");
		}
	else {
		&job_error($text{'backup_eok'});
		}

	print "</pre>";
	}
print "</dl>\n";
&close_console($h);
&webmin_log("gbackup", $in{'job'});

&ui_print_footer("", $text{'index_return'});

sub job_error
{
print "</pre>\n";
print "<b>",@_,"</b><p>\n";
&close_console($h);
&ui_print_footer("backup_form.cgi", $text{'backup_return'});
exit;
}

