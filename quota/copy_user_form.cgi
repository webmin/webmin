#!/usr/local/bin/perl
# copy_user_form.cgi
# Display a form for copying some user's quotas to others

require './quota-lib.pl';
&ReadParse();
$access{'filesys'} eq "*" ||
	&error($text{'cuform_ecannot'});
&can_edit_user($in{'user'}) ||
	&error($text{'cuform_euallow'});
&ui_print_header(undef, $text{'cuform_title'}, "", "copy_user");

print "<form action=copy_user.cgi>\n";
print "<input type=hidden name=user value=\"$in{'user'}\">\n";
print "<b>",&text('cuform_copyto', $in{'user'}),"</b><p>\n";
print "<ul>\n";
print "<input type=radio name=dest value=0> ",
      "<b>$text{'cuform_all'}</b><br>\n";
print "<input type=radio name=dest value=1 checked> ",
      "<b>$text{'cuform_select'}</b>\n";
print "<input name=users size=30> ",&user_chooser_button("users",1),"<br>\n";
print "<input type=radio name=dest value=2> ",
      "<b>$text{'cuform_members'}</b>\n";
print "<input name=groups size=30> ",&group_chooser_button("groups",1),"<br>\n";
print "<input type=submit value=$text{'cuform_doit'}></form>\n";
print "</ul>\n";

&ui_print_footer("user_filesys.cgi?user=$in{'user'}", $text{'cuform_return'});
