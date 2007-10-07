#!/usr/local/bin/perl
# edit_db.cgi
# Edit or create a db table record

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'db_title1'}, "", "create_db");
	}
else {
	$d = &execute_sql_safe($master_db, "select * from db order by db");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	&ui_print_header(undef, $text{'db_title2'}, "", "edit_db");
	}

print "<form action=save_db.cgi>\n";
if ($in{'new'}) {
	print "<input type=hidden name=new value=1>\n";
	}
else {
	print "<input type=hidden name=oldhost value='$u->[0]'>\n";
	print "<input type=hidden name=olddb value='$u->[1]'>\n";
	print "<input type=hidden name=olduser value='$u->[2]'>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'db_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'db_db'}</b></td>\n";
print "<td>",&select_db($u->[1]),"</td> </tr>\n";

print "<tr> <td><b>$text{'db_user'}</b></td> <td>\n";
printf "<input type=radio name=user_def value=1 %s> %s\n",
	$u->[2] ? '' : 'checked', $text{'db_anon'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$u->[2] ? 'checked' : '';
print "<input name=user size=20 value='$u->[2]'></td> </tr>\n";

print "<tr> <td><b>$text{'db_host'}</b></td> <td>\n";
printf "<input type=radio name=host_mode value=0 %s> %s\n",
	$u->[0] eq '' ? 'checked' : '', $text{'db_hosts'};
printf "<input type=radio name=host_mode value=1 %s> %s\n",
	$u->[0] eq '%' ? 'checked' : '', $text{'db_any'};
printf "<input type=radio name=host_mode value=2 %s>\n",
	$u->[0] eq '%' || $u->[0] eq '' ? '' : 'checked';
printf "<input name=host size=40 value='%s'></td> </tr>\n",
	$u->[0] eq '%' ? '' : $u->[0];

print "<tr> <td valign=top><b>$text{'db_perms'}</b></td>\n";
print "<td><select name=perms multiple size=8>\n";
for($i=3; $i<=&db_priv_cols()+3-1; $i++) {
	printf "<option value=%d %s>%s\n",
		$i, $u->[$i] eq 'Y' ? 'selected' : '',
		$text{"db_priv$i"};
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'>\n";
if (!$in{'new'}) {
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer('list_dbs.cgi', $text{'dbs_return'},
	"", $text{'index_return'});

