#!/usr/local/bin/perl
# backup.cgi
# Run a filesystem backup, either in the background or foreground (and show
# the results)

require './fsdump-lib.pl';
&ReadParse();
$dump = &get_dump($in{'id'});
$dump->{'id'} || &error($text{'backup_egone'});
&can_edit_dir($dump) || &error($text{'backup_ecannot'});

if ($config{'run_mode'}) {
	# Background
	&ui_print_header(undef, $text{'backup_title'}, "");

	print "<p>$text{'backup_bg'}<p>\n";
	&clean_environment();
	&system_logged("$cron_cmd ".quotemeta($dump->{'id'}).
	       " >/dev/null 2>&1 </dev/null &");
	&reset_environment();
	&webmin_log("bgbackup", undef, undef, $dump);
	}
else {
	# Foreground
	&ui_print_unbuffered_header(undef, $text{'backup_title'}, "");

	# Setup command to be called upon tape change (which is not
	# supported in this mode)
	$nfile = "$module_config_directory/$dump->{'id'}.notape";
	unlink($nfile);
	&create_wrappers();

	print "<b>",&text('backup_desc',
			     "<tt>".&html_escape($dump->{'dir'})."</tt>",
			     &dump_dest($dump)),"</b><p>\n";
	print "<pre>";
	$bok = &execute_before($dump, STDOUT, 1);
	if (!$bok && !$dump->{'beforefok'}) {
		# Before command failed
		print "</pre>\n";
		print "<b>$text{'backup_beforefailed'}</b><p>\n";
		}
	else {
		# Do the dump
		$now = time();
		$ok = &execute_dump($dump, STDOUT, 1, 0, $now);
		print "</pre>\n";
		if (!$bok) {
			print "<b>$text{'backup_afterfailed'}</b><p>\n";
			}
		elsif ($ok) {
			# Worked .. but verify if asked
			if ($dump->{'reverify'}) {
				print "<b>$text{'backup_reverify'}</b><p>\n";
				print "<pre>";
				$ok = &verify_dump($dump, STDOUT, 1, 0, $now);
				print "</pre>";
				}
			if ($ok) {
				print "<b>$text{'backup_done'}</b><br>\n";
				}
			else {
				print "<b>$text{'backup_noverify'}</b><br>\n";
				}
			}
		else {
			if (-r $nfile) {
				print "<b>$text{'backup_notape'}</b><br>\n";
				}
			else {
				print "<b>$text{'backup_failed'}</b><br>\n";
				}
			}

		# Execute the post-backup command, if any
		if ($ok || $dump->{'afteraok'}) {
			print "<pre>";
			$bok = &execute_after($dump, STDOUT, 1);
			print "</pre>\n";
			}
		}
	unlink($nfile);
	delete($dump->{'pass'});
	&webmin_log("backup", undef, undef, $dump);
	}

&ui_print_footer($access{'edit'} ? ( "edit_dump.cgi?id=$in{'id'}",
			     $text{'edit_return'} ) : ( ),
	"", $text{'index_return'});

