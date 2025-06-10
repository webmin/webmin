#!/usr/local/bin/perl
# flushq.cgi
# Run postqueue -f and display the output

require './postfix-lib.pl';
&ui_print_unbuffered_header(undef, $text{'flushq_title'}, "");

$cmd = "$config{'postfix_queue_command'} -c $config_dir -f";
print &text('flushq_desc', "<tt>$cmd</tt>"),"<br>\n";
$out = &backquote_logged("$cmd 2>&1 </dev/null");
print "<pre>",&html_escape($out),"</pre>\n" if ($out =~ /\S/);
print $text{'flushq_desc2'},"<p>\n";
&webmin_log("flushq");

&ui_print_footer("mailq.cgi", $text{'mailq_return'});

