#!/usr/local/bin/perl
# edit_filter.cgi
# Display allowed user filter options

require './jabber-lib.pl';
&ui_print_header(undef, $text{'filter_title'}, "", "filter");

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$jsm = &find("jsm", $session);
$filter = &find("filter", $jsm);

print "<form action=save_filter.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'filter_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'filter_max'}</b></td>\n";
printf "<td><input name=max size=6 value='%s'></td> </tr>\n",
	&find_value("max_size", $filter);

$allow = &find("allow", $filter);

$conds = &find("conditions", $allow);
print "<tr> <td valign=top><b>$text{'filter_conds'}</b></td> <td>\n";
foreach $c (@filter_conds) {
	$cx = &find($c, $conds);
	printf "<input type=checkbox name=%s value=1 %s> %s\n",
		"cond_$c", $cx ? "checked" : "", $c;
	}
print "</td> </tr>\n";

$acts = &find("actions", $allow);
print "<tr> <td valign=top><b>$text{'filter_acts'}</b></td> <td>\n";
foreach $c (@filter_acts) {
	$cx = &find($c, $acts);
	printf "<input type=checkbox name=%s value=1 %s> %s\n",
		"act_$c", $cx ? "checked" : "", $c;
	}
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

