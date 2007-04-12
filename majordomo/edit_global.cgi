#!/usr/local/bin/perl
# edit_global.cgi
# Edit global majordomo options

require './majordomo-lib.pl';
$conf = &get_config();
%access = &get_module_acl();
$access{'global'} || &error($text{'global_ecannot'});
&ui_print_header(undef, $text{'global_title'}, "");

print "<form action=save_global.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'global_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

$whereami = &find_value("whereami", $conf);
print "<tr> <td><b>$text{'global_whereami'}</b></td>\n";
print "<td><input name=whereami size=30 value=\"$whereami\"></td> </tr>\n";

$whoami = &find_value("whoami", $conf);
print "<tr> <td><b>$text{'global_whoami'}</b></td>\n";
print "<td><input name=whoami size=40 value=\"$whoami\"></td> </tr>\n";

$whoami_o = &find_value("whoami_owner", $conf);
print "<tr> <td><b>$text{'global_owner'}</b></td>\n";
print "<td><input name=whoami_owner size=40 value=\"$whoami_o\"></td> </tr>\n";

$sendmail = &find_value("sendmail_command", $conf);
print "<tr> <td><b>$text{'global_sendmail'}</b></td>\n";
print "<td><input name=sendmail_command size=40 value=\"$sendmail\">",
	&file_chooser_button("sendmail_command", 0),"</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});
