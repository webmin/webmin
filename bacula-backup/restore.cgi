#!/usr/local/bin/perl
# Actually execute the restore

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'restore_err'});
$dbh = &connect_to_database();

# Validate inputs
@files = split(/\r?\n/, $in{'files'});
@files || &error($text{'restore_efiles'});
$in{'where'} =~ s/\\/\//g;
$in{'where_def'} || $in{'where'} =~ /^([a-zA-Z]:)?\// ||
	&error($text{'restore_ewhere'});
$in{'client'} || &error($text{'restore_eclient'});
if ($in{'job'} =~ /^nj_(.*)_(\d+)_(\d+)$/) {
	# Node group job restore ..
	$in{'client'} eq "*" || &error($text{'restore_eall1'});
	$name = $1;
	$time = $2;
	}
else {
	# Single job restore
	$in{'client'} eq "*" && &error($text{'restore_eall2'});

	# Get the job name
	$cmd = $dbh->prepare("select Name from Job where JobId = ?");
	$cmd->execute($in{'job'});
	($name) = $cmd->fetchrow();
	$cmd->finish();
	}

# Work out clients to restore to
if ($in{'client'} eq "*") {
	# Clients that were originally backed up
	$cmd = $dbh->prepare("select Job.JobId,Job.Name,Job.SchedTime,Client.Name from Job,Client where Job.Name not like 'Restore%' and Job.ClientId = Client.ClientId order by SchedTime desc");
	$cmd->execute();
	while(my ($jid, $jname, $jwhen, $jclient) = $cmd->fetchrow()) {
		($j, $c) = &is_oc_object($jname);
		$stime = &date_to_unix($jwhen);
		if ($j && $c && $j eq $name) {
			if (abs($stime - $time) < 30) {
				# Found a member of the group
				push(@clients, [ $jclient, $jid ]);
				}
			}
		}
	$cmd->finish();
	@clients || &error($text{'restore_eclients'});
	&ui_print_unbuffered_header(undef,  $text{'restore_title3'}, "", "restore");
	}
elsif ($g = &is_oc_object($in{'client'})) {
	# All clients in a node group
	($group) = grep { $_->{'name'} eq $g } &list_node_groups();
	$group || &error($text{'restore_egroup'});
	@clients = map { [ "occlient_${g}_".$_, $in{'job'} ] } @{$group->{'members'}};
	&ui_print_unbuffered_header(undef,  $text{'restore_title2'}, "", "restore");
	}
else {
	# Just one
	&ui_print_unbuffered_header(undef,  $text{'restore_title'}, "", "restore");
	@clients = ( [ $in{'client'}, $in{'job'} ] );
	}

foreach $clientjob (@clients) {
	$client = $clientjob->[0];
	$job = $clientjob->[1];
	($g, $c) = &is_oc_object($name);
	($gc, $cc) = &is_oc_object($client);
	print "<b>",&text('restore_run', $c ? "<tt>$c</tt>" : "<tt>$name</tt>", $cc ? "<tt>$cc</tt>" : "<tt>$client</tt>", "<tt>$in{'storage'}</tt>"),"</b>\n";
	print "<pre>";
	$h = &open_console();

	# Clear messages
	&console_cmd($h, "messages");

	# Start the restore process
	&sysprint($h->{'infh'}, "restore client=$client jobid=$job storage=$in{'storage'}".($in{'where_def'} ? "" : " where=\"$in{'where'}\"")."\n");
	&wait_for($h->{'outfh'}, 'restore.*\n');
	print $wait_for_input;
	$rv = &wait_for($h->{'outfh'}, 'Enter\s+"done".*\n',
				       'Unable to get Job record',
				       'all the files');
	print $wait_for_input;
	if ($rv == 1) {
		&job_error($text{'restore_ejob'});
		}
	elsif ($rv == 2) {
		&job_error($text{'restore_ejobfiles'});
		}

	# Select the files
	&wait_for($h->{'outfh'}, "\\\$");	# Wait for first prompt
	print $wait_for_input;
	foreach $f (@files) {
		$f = &unix_to_dos($f);
		if ($f eq "/") {
			&sysprint($h->{'infh'}, "cd /\n");
			&wait_for($h->{'outfh'}, "\\\$");
			print $wait_for_input;

			&sysprint($h->{'infh'}, "mark *\n");
			&wait_for($h->{'outfh'}, "\\\$");
			print $wait_for_input;
			}
		elsif ($f =~ /^(.*)\/([^\/]+)\/?$/) {
			local ($fd, $ff) = ($1, $2);
			$fd ||= "/";
			&sysprint($h->{'infh'}, "cd \"$fd\"\n");
			&wait_for($h->{'outfh'}, "\\\$");
			print $wait_for_input;

			&sysprint($h->{'infh'}, "mark \"$ff\"\n");
			&wait_for($h->{'outfh'}, "\\\$");
			print $wait_for_input;
			}
		}
	&sysprint($h->{'infh'}, "done\n");
	$rv = &wait_for($h->{'outfh'}, 'OK to run.*:', 'no files selected',
				       'Select Restore Job.*:');
	print $wait_for_input;
	if ($rv == 0) {
		&sysprint($h->{'infh'}, "yes\n");
		}
	elsif ($rv == 1) {
		&job_error($text{'restore_enofiles'});
		}
	elsif ($rv == 2) {
		&sysprint($h->{'infh'}, "1\n");
		&wait_for($h->{'outfh'}, 'OK to run.*:');
		&sysprint($h->{'infh'}, "yes\n");
		}
	else {
		&job_error($text{'backup_eok'});
		}
	print "</pre>\n";

	if ($in{'wait'}) {
		# Wait till we have a status
		print "</pre>\n";
		print "<b>",$text{'restore_running'},"</b>\n";
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
		if ($status =~ /Restore\s+OK/i && $status !~ /warning/i) {
			print "<b>",$text{'restore_done'},"</b><p>\n";
			}
		else {
			print "<b>",$text{'restore_failed'},"</b><p>\n";
			}
		}
	else {
		# Let it fly
		print "<b>",$text{'restore_running2'},"</b><p>\n";
		}

	&close_console($h);
	}

&webmin_log("restore", $in{'job'});

&ui_print_footer("restore_form.cgi", $text{'restore_return'});

sub job_error
{
&close_console($h);
print "</pre>\n";
print "<b>",@_,"</b><p>\n";
&ui_print_footer("backup_form.cgi", $text{'backup_return'});
exit;
}

