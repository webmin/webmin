#!/usr/local/bin/perl
# start_stop.cgi
# Start or stop a boot-time action

require './init-lib.pl';
&foreign_require("proc", "proc-lib.pl");
$access{'bootup'} || &error($text{'ss_ecannot'});
&ReadParse();

$| = 1;
$theme_no_header = 1;
if (defined($in{'start'})) {
	&ui_print_header(undef, $text{'ss_start'}, "");
	$cmd = "$in{'file'} start";
	}
elsif (defined($in{'restart'})) {
	&ui_print_header(undef, $text{'ss_restart'}, "");
	$cmd = "$in{'file'} restart";
	}
elsif (defined($in{'condrestart'})) {
	&ui_print_header(undef, $text{'ss_restart'}, "");
	$cmd = "$in{'file'} condrestart";
	}
elsif (defined($in{'reload'})) {
	&ui_print_header(undef, $text{'ss_reload'}, "");
	$cmd = "$in{'file'} reload";
	}
elsif (defined($in{'status'})) {
	&ui_print_header(undef, $text{'ss_status'}, "");
	$cmd = "$in{'file'} status";
	}
else {
	&ui_print_header(undef, $text{'ss_stop'}, "");
	$cmd = "$in{'file'} stop";
	}
print &text('ss_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>";
&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";
&webmin_log($in{'start'} ? 'start' : 'stop', 'action', $in{'name'});
&ui_print_footer($in{'back'}, $text{'edit_return'});

