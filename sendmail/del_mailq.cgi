#!/usr/local/bin/perl
# del_mailq.cgi
# Delete some mail message from the queue

require './sendmail-lib.pl';
require './boxes-lib.pl';
&ReadParse();

if ($in{'flush'}) {
	# Just go to flushing page
	&redirect("del_mailqs.cgi?flush=1&file=".&urlize($in{'file'}));
	exit;
	}

&error_setup($text{'delq_err'});
$access{'mailq'} == 2 || &error($text{'delq_ecannot'});
$in{'file'} =~ /\.\./ && &error($text{'delq_ecannot'});
$conf = &get_sendmailcf();
foreach $mqueue (&mailq_dir($conf)) {
	$ok++ if ($in{'file'} =~ /^$mqueue\//);
	}
$ok || &error($text{'mailq_ecannot'});

$qfile = $in{'file'};
$mail = &mail_from_queue($qfile, "auto");
&can_view_qfile($mail) || &error($text{'delq_ecannot'});

if (-r $mail->{'lfile'} && !$in{'force'}) {
	&ui_print_header(undef, $text{'delq_title'}, "");
	print "<center><form action=del_mailq.cgi>\n";
	print "<b>$main::whatfailed : $text{'delq_locked'}</b><p>\n";
	print "<input type=hidden name=file value='$in{'file'}'>\n";
	print "<input type=submit name=force value='$text{'delq_force'}'>\n";
	print "</form></center>\n";
	&ui_print_footer("list_mailq.cgi", $text{'mailq_return'});
	exit;
	}

unlink($mail->{'file'}, $mail->{'dfile'}, $mail->{'lfile'});
&webmin_log("delmailq", undef, undef, { 'to' => $mail->{'header'}->{'to'},
					'from' => $mail->{'header'}->{'from'} });
&redirect("list_mailq.cgi");

