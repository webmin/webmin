#!/usr/local/bin/perl
# delete_queue.cgi
# Delete multiple mail messages from the queue

require './qmail-lib.pl';
&ReadParse();

@files = split(/\0/, $in{'file'});
if ($in{'confirm'}) {
	# Delete messages
	$pid = &is_qmail_running();
	if ($pid) {
		&stop_qmail();
		}

	foreach $f (@files) {
		$f =~ /(\d+)\/(\d+)$/;
		$id = "$1/$2";
		unlink("$qmail_mess_dir/$id");
		unlink("$qmail_info_dir/$id");
		unlink("$qmail_remote_dir/$id");
		unlink("$qmail_local_dir/$id");
		}

	($newpid) = &find_byname("qmail-send");
	if ($pid && !$newpid) {
		# Need to re-start qmail
		&start_qmail();
		}

	&redirect("list_queue.cgi");
	}
else {
	# Ask for confirmation first
	&ui_print_header(undef, $text{'delq_titles'}, "");
	print "<center>\n";
	print &ui_form_start("delete_queues.cgi", "post");
	print &text('delq_rusure', scalar(@files)),"<p>\n";
	foreach $f (@files) {
		print &ui_hidden("file", $f),"\n";
		}
	print &ui_form_end([ [ "confirm", $text{'delq_confirm'} ] ]);
	print "</center>\n";
	&ui_print_footer("list_queue.cgi", $text{'queue_return'});
	}

