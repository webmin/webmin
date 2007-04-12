#!/usr/local/bin/perl
# push.cgi
# Push the current configuration out to clients with cfrun

require './cfengine-lib.pl';
&ui_print_unbuffered_header(undef, $text{'push_title2'}, "");

$cmd = "cfrun";
print "<p>",&text('push_exec', "<tt>$cmd</tt>"),"<br>\n";
print "<pre>";
$ENV{'CFINPUTS'} = $config{'cfengine_dir'};
chdir($config{'cfengine_dir'});
open(CMD, "$cmd 2>&1 </dev/null |");
while(<CMD>) {
	print &html_escape($_);
	}
close(CMD);
&additional_log("exec", undef, $cmd);
print "</pre>\n";
&webmin_log("prun");

&ui_print_footer("edit_push.cgi", $text{'push_return'},
	"", $text{'index_return'});

