#!/usr/local/bin/perl
# test_print.cgi
# Print one of the test pages

require './lpadmin-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&ReadParseMime();
$access{'test'} || &error($text{'test_ecannot'});
&ui_print_header(&text('jobs_on', "<tt>$in{'name'}</tt>"),
		 $text{'test_title'}, "");

if ($in{'mode'} == 0) {
	$file = "bw.ps";
	}
elsif ($in{'mode'} == 1) {
	$file = "colour.ps";
	}
elsif ($in{'mode'} == 2) {
	$file = "ascii.txt";
	}
else {
	$file = &transname();
	&open_tempfile(FILE, ">$file", 0, 1);
	&print_tempfile(FILE, $in{'file'});
	&close_tempfile(FILE);
	}

$cmd = &print_command($in{'name'}, $file);
if ($access{'user'} eq '*') {
	# Run as root
	}
elsif ($access{'user'}) {
	$cmd = &command_as_user($access{'user'}, 0, $cmd);
	}
else {
	$cmd = &command_as_user($remote_user, 0, $cmd);
	}

print &text('test_exec', "<tt>$cmd</tt>"),"<br>\n";
print "<pre>";
&open_execute_command(CMD, $cmd, 1);
while(<CMD>) {
	print;
	}
close(CMD);
print "</pre>\n";

if ($?) { print "<b>$text{'test_failed'}</b> <p>\n"; }
else { print "$text{'test_ok'} <p>\n"; }

unlink($file) if ($in{'mode'} == 3);
&ui_print_footer("list_jobs.cgi?name=".&urlize($in{'name'}),
		  $text{'jobs_return'},
		 "", $text{'index_return'});

