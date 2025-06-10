#!/usr/local/bin/perl
# flushq.cgi
# Run sendmail -vq and display the output

require './sendmail-lib.pl';
$access{'flushq'} || &error($text{'flushq_ecannot'});
&ui_print_unbuffered_header(undef, $text{'flushq_title'}, "");
&ReadParse();

$qopt = $in{'quar'} ? "-qQ" : "-q";
$oopt = $config{'mailq_order'} ? "-O QueueSortOrder=$config{'mailq_order'}" :"";
$cmd = "$config{'sendmail_path'} -v $qopt $oopt -C$config{'sendmail_cf'}";
print &text('flushq_desc', "<tt>$cmd</tt>"),"\n";
print "<pre>";
&foreign_require("proc", "proc-lib.pl");
&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";
&webmin_log("flushq");

&ui_print_footer("list_mailq.cgi", $text{'mailq_return'});

