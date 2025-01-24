#!/usr/local/bin/perl
# Run rotate.pl now

require './bandwidth-lib.pl';
&ui_print_unbuffered_header(undef, $text{'rotate_title'}, "");
print &ui_text_wrap($text{'rotate_doing'});
my ($out) = &backquote_logged("$cron_cmd 2>&1");
$out = $out ? &text('rotate_failed', &html_strip($out)) : $text{'rotate_done'};
print &ui_text_wrap("<br>$out");
&webmin_log("rotate");
&ui_print_footer("", $text{'index_return'});

