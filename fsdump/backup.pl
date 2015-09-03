#!/usr/local/bin/perl
# backup.pl
# Perform a backup and send the results to someone

$no_acl_check++;
require './fsdump-lib.pl';
$dump = &get_dump($ARGV[0]);
$dump->{'id'} || die "Dump $ARGV[0] does not exist!";

# Check if this backup is already running
&foreign_require("proc", "proc-lib.pl");
@procs = &proc::list_processes();
@running = &running_dumps(\@procs);
($running) = grep { $_->{'id'} eq $dump->{'id'} &&
		    $_->{'pid'} != $$ } @running;

$sfile = "$module_config_directory/$dump->{'id'}.$$.status";
if ($running) {
	# Already running! Do nothing ..
	$ok = 0;
	$out = &text('email_already', $running->{'pid'})."\n";
	}
else {
	# Update status file
	%status = ( 'status' => 'running',
		    'pid' => $$,
		    'start' => time() );
	&write_file($sfile, \%status);

	if ($dump->{'email'}) {
		# Save output for mailing
		$temp = &transname();
		open(OUT, ">$temp");
		}
	else {
		# Throw output away
		open(OUT, ">/dev/null");
		}

	# Create tape change wrapper
	&create_wrappers();

	$bok = &execute_before($dump, OUT, 0);
	if (!$bok && !$dump->{'beforefok'}) {
		# Before command failed!
		print OUT "\n$text{'email_ebefore'}\n";
		$status{'status'} = 'failed';
		}
	else {
		# Do the backup
		$now = time();
		$ok = &execute_dump($dump, OUT, 0, 1, $now);

		# Re-update the status file
		if ($ok) {
			# Worked .. but verify if asked
			if ($dump->{'reverify'}) {
				print OUT "\n$text{'email_verify'}\n";
				$ok = &verify_dump($dump, OUT, 0, 1, $now);
				}
			if ($ok) {
				$status{'status'} = 'complete';
				}
			else {
				$status{'status'} = 'verifyfailed';
				}
			}
		else {
			$status{'status'} = 'failed';
			}
		}
	$status{'end'} = time();
	&write_file($sfile, \%status);

	if ($status{'status'} eq 'complete' || $dump->{'afteraok'}) {
		# Execute the post-backup script
		$bok = &execute_after($dump, OUT, 0);
		if (!$bok && !$dump->{'afterfok'}) {
			print OUT "\n$text{'email_eafter'}\n";
			$status{'status'} = 'failed';
			$ok = 0;
			}
		}
	close(OUT);

	if ($temp) {
		# Read output
		open(OUT, $temp);
		while(<OUT>) {
			s/\r//g;
			$out .= $_;
			}
		close(OUT);
		unlink($temp);
		}
	}

if ($out && $dump->{'email'} && &foreign_check("mailboxes")) {
	# Construct the email
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	$host = &get_system_hostname();
	@dirs = &dump_directories($dump);
	$dirs = join(", ", @dirs);
	%hash = ( %$dirs, 'dirs' => $dirs );
	local $subject = &substitute_template($dump->{'subject'}, \%hash) ||
			 &text('email_subject', $dirs, $host);
	local $data = &text('email_subject', $dirs, $host)."\n\n";
	$data .= $out;
	$data .= "\n";
	if ($ok) {
		$data .= $text{'email_ok'}."\n";
		}
	else {
		$data .= $text{'email_failed'}."\n";
		}

	# Send the email
	if (!$ok || !$config{'error_email'}) {
		# Only send email upon failure, or it requested always
		&mailboxes::send_text_mail(&mailboxes::get_from_address(),
					   $dump->{'email'},
					   undef,
					   $subject,
					   $data,
					   $config{'smtp_server'});
		}
	}

# Check for any dumps scheduled to run after this one
foreach $follow (&list_dumps()) {
	if ($follow->{'follow'} eq $dump->{'id'} && $follow->{'enabled'} == 2) {
		system("$cron_cmd $follow->{'id'}");
		}
	}

