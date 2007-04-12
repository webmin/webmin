#!/usr/local/bin/perl
# check_quotas.cgi
# Runs quotacheck to update block and file counts on some filesystem

require './quota-lib.pl';
&ReadParse();
&can_edit_filesys($in{'filesys'}) ||
	&error($text{'check_ecannot'});

&ui_print_unbuffered_header(undef, $text{'check_title'}, "");
print &text('check_running', $in{'filesys'}), "<p>\n";

&quotacheck($in{'filesys'}, $in{'source'} eq 'user' ? 1 : 2);
&webmin_log("check", undef, $in{'filesys'});
print "$text{'check_done'}<p>\n";
if ($in{'source'} eq "user") {
	$retlist_name = $text{'check_ruser'};
} else {
	$retlist_name = $text{'check_rgroup'};
}
&ui_print_footer("list_$in{'source'}s.cgi?dir=".&urlize($in{'filesys'}),
	&text('check_return', $retlist_name));

