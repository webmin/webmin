#!/usr/local/bin/perl
# apply.cgi
# Call lilo to apply the current config

require './lilo-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&ui_print_unbuffered_header(undef, $text{'apply_title'}, "");
print "<p>\n";
$cmd = "$config{'lilo_cmd'} -v";
print &text('apply_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>";
&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT);
&webmin_log("apply");
print "</pre>\n";
&ui_print_footer("", $text{'index_return'});

