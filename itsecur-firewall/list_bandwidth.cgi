#!/usr/bin/perl
# Show a form for setting up bandwidth monitoring

require './itsecur-lib.pl';
&can_edit_error("bandwidth");
&header($text{'bandwidth_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=save_bandwidth.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'bandwidth_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'bandwidth_enabled'}</b></td> <td>\n";
printf "<input type=radio name=enabled value=0 %s> %s\n",
	$config{'bandwidth'} ? "" : "checked", $text{'no'};
printf "<input type=radio name=enabled value=1 %s> %s\n",
	$config{'bandwidth'} ? "checked" : "", $text{'bandwidth_yes'};
print &iface_input("iface", $config{'bandwidth'}, 1, 1, 0);
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

print "<hr>\n";
&footer("", $text{'index_return'});

