#!/usr/local/bin/perl
# edit_netgroup.cgi
# Edit a NIS netgroup table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'netgroup_title'}, "");

($t, $lnums, $netgroup) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
print "<form action=save_netgroup.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'netgroup_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'netgroup_name'}</b></td>\n";
print "<td><input name=name size=15 value='$netgroup->[0]'></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'netgroup_members'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'netgroup_host'}</b></td> ",
      "<td><b>$text{'netgroup_user'}</b></td> ",
      "<td><b>$text{'netgroup_domain'}</b></td> </tr>\n";
$i = 0;
foreach $h (@$netgroup[1 .. @$netgroup-1], "(x,,)", "(x,,)") {
	$h =~ /^\((\S*),(\S*),(\S*)\)$/ || next;
	print "<tr $cb>\n";
	foreach $v (['host',$1],['user',$2],['dom',$3]) {
		printf "<td><input type=radio name=$v->[0]_def_$i value=1 %s>%s\n",
			$v->[1] ? '' : 'checked', $text{'netgroup_any'};
		printf "<input type=radio name=$v->[0]_def_$i value=2 %s>%s\n",
			$v->[1] eq 'x' ? 'checked' : '', $text{'netgroup_none'}
			if ($v->[0] eq 'host');
		printf "<input type=radio name=$v->[0]_def_$i value=0 %s>\n",
			$v->[1] && $v->[1] ne 'x' ? 'checked' : '';
		printf "<input name=$v->[0]_$i size=15 value='%s'></td>\n",
			$v->[1] eq "x" ? "" : $v->[1];
		}
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
if (defined($in{'line'})) {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
else {
	print "<input type=submit value='$text{'create'}'>\n";
	}
print "</form>\n";
&ui_print_footer("edit_tables.cgi?table=$in{'table'}", $text{'tables_return'},
	"", $text{'index_return'});

