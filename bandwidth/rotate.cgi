#!/usr/local/bin/perl
# Run rotate.pl now

require './bandwidth-lib.pl';
&ui_print_header(undef, $text{'rotate_title'}, "");

print "<b>$text{'rotate_doing'}</b>\n";
print "<pre>";
open(OUT, "$cron_cmd 2>&1 |");
while(<OUT>) {
	print &html_escape($_);
	}
close(OUT);
print "</pre>\n";
print "<b>$text{'rotate_done'}</b><p>\n";

&webmin_log("rotate");
&ui_print_footer("", $text{'index_return'});

