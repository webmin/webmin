#!/usr/local/bin/perl
# list_groups.cgi
# Display a list of all host groups and their members

require './mon-lib.pl';
&ui_print_header(undef, $text{'groups_title'}, "");

$conf = &get_mon_config();
@groups = &find("hostgroup", $conf);

print "<form action=save_groups.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'groups_group'}</b></td> ",
      "<td><b>$text{'groups_members'}</b></td> </tr>\n";
$i = 0;
foreach $g (@groups, { }) {
	local ($gn, @gm) = @{$g->{'values'}};
	print "<tr $cb>\n";
	print "<td><input name=group_$i size=20 value='$gn'></td>\n";
	print "<td><input name=members_$i size=60 value='",
		join(" ", @gm),"'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

