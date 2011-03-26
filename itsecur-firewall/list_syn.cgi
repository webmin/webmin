#!/usr/bin/perl
# list_syn.cgi
# Show syn attack prevention form

require './itsecur-lib.pl';
&can_use_error("syn");
&header($text{'syn_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=save_syn.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'syn_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

($flood, $spoof, $fin) = &get_syn();

print "<tr> <td><b>$text{'syn_flood'}</b></td> <td>\n";
printf "<input type=radio name=flood value=1 %s> %s\n",
	$flood ? "checked" : "", $text{'yes'};
printf "<input type=radio name=flood value=0 %s> %s</td> </tr>\n",
	$flood ? "" : "checked", $text{'no'};

print "<tr> <td><b>$text{'syn_spoof'}</b></td> <td>\n";
printf "<input type=radio name=spoof value=1 %s> %s\n",
	$spoof ? "checked" : "", $text{'yes'};
printf "<input type=radio name=spoof value=0 %s> %s</td> </tr>\n",
	$spoof ? "" : "checked", $text{'no'};

print "<tr> <td><b>$text{'syn_fin'}</b></td> <td>\n";
printf "<input type=radio name=fin value=1 %s> %s\n",
	$fin ? "checked" : "", $text{'yes'};
printf "<input type=radio name=fin value=0 %s> %s</td> </tr>\n",
	$fin ? "" : "checked", $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";
&can_edit_disable("syn");

print "<hr>\n";
&footer("", $text{'index_return'});
