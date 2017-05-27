#!/usr/local/bin/perl
# edit_head.cgi
# Edit headers and footers

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'head_title'}, "");

print "<form action=save_head.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'head_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print &multi_input("message_fronter", $text{'head_fronter'}, $conf);
print "</tr>\n";

print "<tr>\n";
print &multi_input("message_footer", $text{'head_footer'}, $conf);
print "</tr>\n";

print "<tr>\n";
print &multi_input("message_headers", $text{'head_headers'}, $conf);
print "</tr>\n";

print "</table></td></tr></table>\n";
print &ui_submit($text{'save'}),"</form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});
