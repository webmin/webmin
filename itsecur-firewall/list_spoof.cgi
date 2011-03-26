#!/usr/bin/perl
# list_spoof.cgi
# Show spoofing prevention form

require './itsecur-lib.pl';
&can_use_error("spoof");
&header($text{'spoof_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=save_spoof.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'spoof_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

($iface, @nets) = &get_spoof();
print "<tr> <td valign=top><b>$text{'spoof_desc'}</b></td> <td>\n";
printf "<input type=radio name=spoof value=0 %s> %s<br>\n",
	$iface ? "" : "checked", $text{'spoof_disabled'};
printf "<input type=radio name=spoof value=1 %s> %s\n",
	$iface ? "checked" : "", $text{'spoof_enabled'};
print &iface_input("iface", $iface);
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'spoof_nets'}</b></td> <td>\n";
print "<textarea name=nets rows=5 cols=40>",
	join("\n", @nets),"</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";
&can_edit_disable("spoof");

print "<hr>\n";
&footer("", $text{'index_return'});
