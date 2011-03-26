#!/usr/bin/perl
# list_pat.cgi
# Show table of incoming forwarded ports

require './itsecur-lib.pl';
&can_use_error("pat");
&header($text{'pat_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

@forwards = &get_pat();
print "<form action=save_pat.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'pat_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td valign=top><b>$text{'pat_forward'}</b></td> ",
      "<td><table border>\n";
print "<tr $tb> <td><b>$text{'pat_service'}</b></td> ",
      "<td><b>$text{'pat_host'}</b></td> ",
      "<td><b>$text{'pat_iface'}</b></td> </tr>\n";
$j = 0;
foreach $f (@forwards, { }, { }, { }) {
	print "<tr $cb>\n";
	print "<td>",&service_input("service_$j", $f->{'service'}, 1),"</td>\n";
	print "<td><input name=host_$j size=30 value='$f->{'host'}'></td>\n";
	print "<td>",&iface_input("iface_$j", $f->{'iface'},
				  0, 1, 1),"</td>\n";
	print "</tr>\n";
	$j++;
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";
&can_edit_disable("pat");

print "<hr>\n";
&footer("", $text{'index_return'});
