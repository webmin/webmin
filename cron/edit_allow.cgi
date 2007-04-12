#!/usr/local/bin/perl
# edit_allow.cgi
# A form for editing the system cron.allow and cron.deny files

require './cron-lib.pl';
$access{'allow'} || &error($text{'allow_ecannot'});
&ui_print_header(undef, $text{'allow_title'}, "");

print "<form action=save_allow.cgi>\n";
print "$text{'allow_desc'} <p>\n";

$allowfile = (-r $config{cron_allow_file});
$denyfile = (-r $config{cron_deny_file});
$nofile = $config{cron_deny_all};
printf "<input type=radio name=mode value=0 %s> %s<br>\n",
	!$allowfile && !$denyfile ? "checked" : "",
	$nofile==0 ? $text{'allow_all1'} :
	$nofile==1 ? $text{'allow_all2'} :
		     $text{'allow_all3'};
printf "<input type=radio name=mode value=1 %s> $text{'allow_allow'}\n",
	$allowfile ? "checked" : "";
printf "<input name=allow size=30 value=\"%s\"> %s<br>\n",
	($allowfile ? join(' ', &list_allowed()) : ""),
	&user_chooser_button("allow", 1);
printf "<input type=radio name=mode value=2 %s> $text{'allow_deny'}&nbsp;\n",
	$denyfile && !$allowfile ? "checked" : "";
printf "<input name=deny size=30 value=\"%s\"> %s<br>\n",
	($denyfile ? join(' ', &list_denied()) : ""),
	&user_chooser_button("deny", 1);

print "<input type=submit value=\"$text{'save'}\">\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

