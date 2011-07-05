#!/usr/local/bin/perl
# delete_queue.cgi
# Delete a mail messsage from the queue

require './qmail-lib.pl';
&ReadParse();

-r $in{'file'} || &error($text{'delete_egone'});
$in{'file'} =~ /(\d+)\/(\d+)$/ || &error($text{'delete_ebogus'});
$id = "$1/$2";
$pid = &is_qmail_running();
if ($pid) {
	&stop_qmail();
	}

unlink("$qmail_mess_dir/$id");
unlink("$qmail_info_dir/$id");
unlink("$qmail_remote_dir/$id");
unlink("$qmail_local_dir/$id");

($newpid) = &find_byname("qmail-send");
if ($pid && !$newpid) {
	# Need to re-start qmail
	&start_qmail();
	}

&redirect("list_queue.cgi");

