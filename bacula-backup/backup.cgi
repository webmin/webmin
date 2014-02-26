#!/usr/local/bin/perl
# Actually execute a backup

require './bacula-backup-lib.pl';
&ui_print_unbuffered_header(undef,  $text{'backup_title'}, "");
&ReadParse();

print "<b>",&text('backup_run', "<tt>$in{'job'}</tt>"),"</b>\n";
print "<pre>";
$h = &open_console();

# Clear messages
&console_cmd($h, "messages");

# Select the job to run
&sysprint($h->{'infh'}, "run\n");
&wait_for($h->{'outfh'}, 'run\\n');
$rv = &wait_for($h->{'outfh'}, 'Select Job.*:', 'OK to run.*:');
print $wait_for_input;
if ($rv != 1) {
	# Only need to enter a job if there is more than one
	if ($rv == 0 && $wait_for_input =~ /(\d+):\s+\Q$in{'job'}\E/) {
		&sysprint($h->{'infh'}, "$1\n");
		}
	else {
		&job_error($text{'backup_ejob'});
		}

	# Say that it is OK
	$rv = &wait_for($h->{'outfh'}, 'OK to run.*:');
	print $wait_for_input;
	}
if ($rv == 0) {
	&sysprint($h->{'infh'}, "yes\n");
	}
else {
	&job_error($text{'backup_eok'});
	}

print "</pre>";

if ($in{'wait'}) {
	# Wait till we have a status
	print "</pre>\n";
	print "<b>",$text{'backup_running'},"</b>\n";
	print "<pre>";
	while(1) {
		$out = &console_cmd($h, "messages");
		if ($out !~ /You\s+have\s+no\s+messages/i) {
			print $out;
			}
		if ($out =~ /Termination:\s+(.*)/) {
			$status = $1;
			last;
			}
		sleep(1);
		}
	print "</pre>\n";
	if ($status =~ /Backup\s+OK/i && $status !~ /warning/i) {
		print "<b>",$text{'backup_done'},"</b><p>\n";
		}
	else {
		print "<b>",$text{'backup_failed'},"</b><p>\n";
		}
	}
else {
	# Let it fly
	print "<b>",$text{'backup_running2'},"</b><p>\n";
	}

&close_console($h);
&webmin_log("backup", $in{'job'});

&ui_print_footer("backup_form.cgi", $text{'backup_return'});

sub job_error
{
&close_console($h);
print "</pre>\n";
print "<b>",@_,"</b><p>\n";
&ui_print_footer("backup_form.cgi", $text{'backup_return'});
exit;
}

