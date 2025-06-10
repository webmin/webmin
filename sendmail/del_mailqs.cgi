#!/usr/local/bin/perl
# del_mailqs.cgi
# Delete some mail messages from the queue

require './sendmail-lib.pl';
require './boxes-lib.pl';
&ReadParse();
@files = split(/\0/, $in{'file'});

if ($in{'flush'}) {
	# Flushing selected messages
	@files || &error($text{'delq_enone'});
	$access{'flushq'} || &error($text{'flushq_ecannot'});
	&ui_print_unbuffered_header(undef, $text{'flushq_title'}, "");

	# Split into quarantined and non-quarantined messages
	local @mails = map { &mail_from_queue($_) } @files;
	local @quar = grep { $_->{'quar'} } @mails;
	local @nonquar = grep { !$_->{'quar'} } @mails;

	foreach $ml (\@quar, \@nonquar) {
		next if (!@$ml);
		@files = map { $_->{'file'} } @$ml;
		$cmd = "$config{'sendmail_path'} -v -C$config{'sendmail_cf'}";
		if ($ml->[0]->{'quar'}) {
			$cmd .= " -qQ";
			}
		foreach $file (@files) {
			$file =~ s/^.*\///;
			$cmd .= " -qI$file";
			}
		if ($config{'mailq_order'}) {
			$cmd .= " -O QueueSortOrder=$config{'mailq_order'}";
			}
		print &text('flushq_desc2', scalar(@files)),"\n";
		print "<pre>";
		&foreign_require("proc", "proc-lib.pl");
		&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0,
			      STDOUT, undef, 1);
		print "</pre>\n";
		}
	&webmin_log("flushq", undef, scalar(@files));
	}
else {
	# Deleting selected messages
	&error_setup($text{'delq_err'});
	$access{'mailq'} == 2 || &error($text{'delq_ecannot'});
	@files || &error($text{'delq_enone'});
	&ui_print_header(undef, $text{'delq_titles'}, "");

	if ($in{'confirm'} || !$config{'delete_confirm'}) {
		# Do it!
		$count = 0;
		$conf = &get_sendmailcf();
		foreach $file (@files) {
			print &text('delq_file', "<tt>$file</tt>"),"&nbsp;&nbsp;&nbsp;\n";

			local $ok;
			foreach $mqueue (&mailq_dir($conf)) {
				$ok++ if ($file =~ /^$mqueue\//);
				}
			if (!$ok) {
				print $text{'delq_efile'},"<br>\n";
				next;
				}

			if ($file =~ /\.\./) {
				print $text{'delq_efile'},"<br>\n";
				next;
				}
			if (!-r $file) {
				print $text{'delq_egone'},"<br>\n";
				next;
				}

			$mail = &mail_from_queue($file, "auto");
			if (!&can_view_qfile($mail)) {
				print $text{'delq_ecannot'},"<br>\n";
				next;
				}

			if (-r $mail->{'lfile'} && !$in{'locked'}) {
				print $text{'delq_elocked'},"<br>\n";
				next;
				}

			unlink($mail->{'file'}, $mail->{'dfile'}, $mail->{'lfile'});
			print $text{'delq_ok'},"<br>\n";
			$count++;
			}
		&webmin_log("delmailq", undef, undef, { 'count' => $count }) if ($count);
		}
	else {
		# Ask for confirmation first
		print "<center>\n";
		print &ui_form_start("del_mailqs.cgi", "post");
		print &text('delq_rusure', scalar(@files)),"<p>\n";
		foreach $f (@files) {
			print &ui_hidden("file", $f),"\n";
			}
		print &ui_hidden("locked", $in{'locked'}),"\n";
		print &ui_form_end([ [ "confirm", $text{'delq_confirm'} ] ]);
		print "</center>\n";
		}
	}
&ui_print_footer("list_mailq.cgi", $text{'mailq_return'});

