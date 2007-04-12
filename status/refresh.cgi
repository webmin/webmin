#!/usr/local/bin/perl
# Run monitor.pl to refresh status

require './status-lib.pl';
&ReadParse();
&ui_print_unbuffered_header(undef, $text{'refresh_title'}, "");

print $text{'refresh_doing'},"<br>\n";
&foreign_require("cron", "cron-lib.pl");
&cron::create_wrapper($cron_cmd, $module_name, "monitor.pl");
system("$cron_cmd --force >/dev/null 2>&1 </dev/null");
print $text{'refresh_done'},"<p>\n";

&ui_print_footer("", $text{'index_return'});


