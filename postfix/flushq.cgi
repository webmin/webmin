#!/usr/local/bin/perl
# flushq.cgi
# Run postqueue -f and display the output

require './postfix-lib.pl';
&ui_print_unbuffered_header(undef, $text{'flushq_title'}, "");

$cmd = "$config{'postfix_queue_command'} -c $config_dir -f";
print &text('flushq_desc', "<tt>$cmd</tt>"),"<br>\n";
print "<pre>";
&foreign_require("proc", "proc-lib.pl");
&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";
&webmin_log("flushq");

&ui_print_footer("mailq.cgi", $text{'mailq_return'});

