#!/usr/local/bin/perl
# edit_admin.cgi
# Display <admin> section options

require './jabber-lib.pl';
&ui_print_header(undef, $text{'admin_title'}, "", "admin");

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$jsm = &find("jsm", $session);
$admin = &find("admin", $jsm);

print "<form action=save_admin.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'admin_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'admin_read'}</b></td>\n";
print "<td><textarea name=read rows=3 cols=50>",
	join("\n", &find_value("read", $admin)),"</textarea></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'admin_write'}</b></td>\n";
print "<td><textarea name=write rows=3 cols=50>",
	join("\n", &find_value("write", $admin)),"</textarea></td> </tr>\n";

$reply = &find("reply", $admin);
print "<tr> <td valign=top><b>$text{'admin_reply'}</b></td>\n";
printf "<td><input type=radio name=reply_def value=1 %s> %s\n",
	$reply ? "" : "checked", $text{'no'};
printf "<input type=radio name=reply_def value=0 %s> %s<br>\n",
	$reply ? "checked" : "", $text{'yes'};
print "<table>\n";
print "<tr> <td><b>$text{'admin_rsubject'}</b></td>\n";
printf "<td><input name=rsubject size=40 value='%s'></td> </tr>\n",
	&find_value("subject", $reply);
print "<tr> <td valign=top><b>$text{'admin_rbody'}</b></td>\n";
print "<td><textarea name=rbody rows=4 cols=40 wrap=auto>",
	&find_value("body", $reply),"</textarea></td> </tr>\n";
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

