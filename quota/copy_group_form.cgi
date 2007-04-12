#!/usr/local/bin/perl
# copy_group_form.cgi
# Display a form for copying some group's quotas to others

require './quota-lib.pl';
&ReadParse();
$access{'filesys'} eq "*" ||
	&error($text{'cgform_ecannot'});
&can_edit_group($in{'group'}) ||
	&error($text{'cgform_egroup'});
&ui_print_header(undef, $text{'cgform_title'}, "", "copy_group");

print "<form action=copy_group.cgi>\n";
print "<input type=hidden name=group value=\"$in{'group'}\">\n";
print "<b>",&text('cgform_copyto', $in{'group'}),"</b><p>\n";
print "<ul>\n";
print "<input type=radio name=dest value=0> ",
      "<b>$text{'cgform_all'}</b><br>\n";
print "<input type=radio name=dest value=1 checked> ",
      "<b>$text{'cgform_select'}</b>\n";
print "<input name=groups size=30> ",&group_chooser_button("groups",1),"<br>\n";
print "<input type=radio name=dest value=2> ",
      "<b>$text{'cgform_contain'}</b>\n";
print "<input name=users size=30> ",&user_chooser_button("users",1),"<br>\n";
print "<input type=submit value=$text{'cgform_doit'}></form>\n";
print "</ul>\n";

&ui_print_footer("group_filesys.cgi?group=$in{'group'}", $text{'cgform_return'});

