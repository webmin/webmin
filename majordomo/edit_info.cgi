#!/usr/local/bin/perl
# edit_info.cgi
# Display a form for editing the intro message for a list

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'info_title'}, "");

print "<form action=save_info.cgi method=post>\n";
print "<input type=hidden name=name value=$in{'name'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'info_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'info_desc'}</b></td>\n";
$desc = &find_value("description", $conf);
print "<td><input name=description size=40 value=\"$desc\"></td> </tr>\n";

print "<tr> <td valign=top><b>",&text('info_info', $in{'name'}),"</b></td>\n";
print "<td><textarea rows=5 cols=80 name=info>\n";
open(INFO, $list->{'info'});
while(<INFO>) {
	print if (!/^\[Last updated on:/);
	}
close(INFO);
print "</textarea></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'info_intro'}</b></td> <td>\n";
$intro = -r $list->{'intro'};
printf "<input type=radio name=intro_def value=1 %s> $text{'info_same'}\n",
	$intro ? "" : "checked";
printf "<input type=radio name=intro_def value=0 %s> $text{'info_below'}<br>\n",
	$intro ? "checked" : "";
print "<textarea rows=5 cols=80 name=intro>\n";
open(INTRO, $list->{'intro'});
while(<INTRO>) {
	print if (!/^\[Last updated on:/);
	}
close(INTRO);
print "</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print &ui_submit($text{'save'}),"</form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

