#!/usr/local/bin/perl
# init.cgi
# Scan for and enable all volume groups

require './lvm-lib.pl';
$theme_no_table++;
$| = 1;
&ui_print_header(undef, $text{'init_title'}, "");

foreach $cmd ("vgscan", "vgchange -a y") {
	print "<b>",&text('init_cmd', "<tt>$cmd</tt>"),"</b><br>\n";
	print "<pre>\n";
	open(CMD, "$cmd 2>&1 |");
	while(<CMD>) {
		print &html_escape($_);
		}
	close(CMD);
	print "</pre>\n";
	}

&ui_print_footer("", $text{'index_return'});

