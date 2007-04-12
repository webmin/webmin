#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'group_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'group_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'group_edit'}, "");
	$s = &execute_sql_safe($config{'basedb'}, "select * from pg_group ".
					     "where grosysid = '$in{'gid'}'");
	@group = @{$s->{'data'}->[0]};
	}

print "<form action=save_group.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'group_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'group_name'}</b></td>\n";
print "<td><input name=name size=20 value='$group[0]'></td>\n";

print "<td><b>$text{'group_id'}</b></td>\n";
if ($in{'new'}) {
	$s = &execute_sql($config{'basedb'},
			  "select max(grosysid) from pg_group");
	$gid = $s->{'data'}->[0]->[0] + 1;
	print "<td><input name=gid size=10 value='$gid'></td> </tr>\n";
	}
else {
	print "<td>$group[1]</td> </tr>\n";
	print "<input type=hidden name=gid value='$in{'gid'}'>\n";
	print "<input type=hidden name=oldname value='$group[0]'>\n";
	}

map { $mem{$_}++ } &split_array($group[2]) if (!$in{'new'});
print "<tr> <td valign=top><b>$text{'group_mems'}</b></td>\n";
print "<td colspan=3><select name=mems multiple size=5 width=200>\n";
$s = &execute_sql($config{'basedb'}, "select * from pg_shadow");
foreach $u (@{$s->{'data'}}) {
	printf "<option value=%s %s>%s\n",
		$u->[1], $mem{$u->[1]} ? 'selected' : '', $u->[0];
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("list_groups.cgi", $text{'group_return'});

