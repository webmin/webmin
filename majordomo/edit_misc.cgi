#!/usr/local/bin/perl
# edit_misc.cgi
# Edit miscellaneous options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'misc_title'}, "");

print "<form action=save_misc.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'misc_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print &choice_input("mungedomain", $text{'misc_munge'},
		    $conf, "yes",$text{'yes'}, "no",$text{'no'});
print &choice_input("debug", $text{'misc_debug'}, $conf,
		    "yes",$text{'yes'}, "no",$text{'no'});
print "</tr>\n";

print "<tr>\n";
print &choice_input("date_info", $text{'misc_info'},
		    $conf, "yes",$text{'yes'}, "no",$text{'no'});
print &choice_input("date_intro", $text{'misc_intro'},
		    $conf, "yes",$text{'yes'}, "no",$text{'no'});
print "</tr>\n";

print "</table></td></tr></table>\n";
print &ui_submit($text{'save'}),"</form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

