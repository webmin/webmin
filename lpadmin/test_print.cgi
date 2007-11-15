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
	open(FILE, ">$file");
	print FILE $in{'file'};
	close(FILE);
	}

$cmd = &print_command($in{'name'}, $file);
print &text('test_exec', "<tt>$cmd</tt>"),"<br>\n";
print "<pre>";
if ($access{'user'} eq '*') {
	open(CMD, "$cmd 2>&1 |");
	}
elsif ($access{'user'}) {
	open(CMD, "su '$access{'user'}' -c '$cmd' 2>&1 |");
	}
else {
	open(CMD, "su '$remote_user' -c '$cmd' 2>&1 |");
	}
while(<CMD>) {
	print;
	}
close(CMD);
print "</pre>\n";

if ($?) { print "<b>$text{'test_failed'}</b> <p>\n"; }
else { print "$text{'test_ok'} <p>\n"; }

unlink($file) if ($in{'mode'} == 3);
&ui_print_footer("", $text{'index_return'});

