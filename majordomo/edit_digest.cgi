#!/usr/local/bin/perl
# edit_digest.cgi
# Edit digest options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'digest_title'}, "");

print "<form action=save_digest.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'digest_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print &opt_input("digest_name", $text{'digest_name'}, $conf,
	  	 $text{'default'}, 40);
print "</tr>\n";

print "<tr>\n";
print &opt_input("digest_maxdays", $text{'digest_maxdays'},
		 $conf, $text{'digest_unlimited'}, 5, $text{'digest_days'});
print &opt_input("digest_maxlines", $text{'digest_maxlines'},
		 $conf, $text{'digest_unlimited'}, 5, $text{'digest_lines'});
print "</tr>\n";

print "<tr>\n";
print &opt_input("digest_volume", $text{'digest_volume'},
		 $conf, $text{'default'}, 4);
print &opt_input("digest_issue", $text{'digest_issue'},
		 $conf, $text{'default'}, 4);
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

