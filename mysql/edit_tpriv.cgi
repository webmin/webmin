#!/usr/local/bin/perl
# edit_tpriv.cgi
# Display a form for editing or creating new table permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});
if ($in{'db'}) {
	&ui_print_header(undef, $text{'tpriv_title1'}, "", "create_tpriv");
	}
else {
	$d = &execute_sql_safe($master_db, "select * from tables_priv order by table_name");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	&ui_print_header(undef, $text{'tpriv_title2'}, "", "edit_tpriv");
	}

print "<form action=save_tpriv.cgi>\n";
if ($in{'db'}) {
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	}
else {
	print "<input type=hidden name=oldhost value='$u->[0]'>\n";
	print "<input type=hidden name=olddb value='$u->[1]'>\n";
	print "<input type=hidden name=olduser value='$u->[2]'>\n";
	print "<input type=hidden name=oldtable value='$u->[3]'>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'tpriv_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'tpriv_db'}</b></td>\n";
print "<td><tt>",$in{'db'} ? $in{'db'} : $u->[1],"</tt></td> </tr>\n";

print "<tr> <td><b>$text{'tpriv_table'}</b></td>\n";
print "<td><select name=table>\n";
print "<option selected>\n" if ($in{'db'});
foreach $t (&list_tables($in{'db'} ? $in{'db'} : $u->[1])) {
	printf "<option %s>%s\n",
		$u->[3] eq $t ? 'selected' : '', $t;
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'tpriv_user'}</b></td> <td>\n";
printf "<input type=radio name=user_def value=1 %s> %s\n",
	$u->[2] ? '' : 'checked', $text{'tpriv_anon'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$u->[2] ? 'checked' : '';
print "<input name=user size=10 value='$u->[2]'></td> </tr>\n";

print "<tr> <td><b>$text{'tpriv_host'}</b></td> <td>\n";
printf "<input type=radio name=host_def value=1 %s> %s\n",
	$u->[0] eq '%' || $u->[0] eq '' ? 'checked' : '', $text{'tpriv_any'};
printf "<input type=radio name=host_def value=0 %s>\n",
	$u->[0] eq '%' || $u->[0] eq '' ? '' : 'checked';
printf "<input name=host size=20 value='%s'></td> </tr>\n",
	$u->[0] eq '%' ? '' : $u->[0];

print "<tr> <td valign=top><b>$text{'tpriv_perms1'}</b></td>\n";
print "<td><select multiple size=4 name=perms1>\n";
foreach $p ('Select','Insert','Update','Delete','Create',
	    'Drop','Grant','References','Index','Alter',
	    ($mysql_version >= 5 ? ('Create View','Show view') : ( ))) {
	printf "<option %s>%s\n",
		$u->[6] =~ /$p/i ? 'selected' : '', $p;
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'tpriv_perms2'}</b></td>\n";
print "<td><select multiple size=4 name=perms2>\n";
foreach $p ('Select','Insert','Update','References') {
	printf "<option %s>%s\n",
		$u->[7] =~ /$p/i ? 'selected' : '', $p;
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'>\n";
if (!$in{'db'}) {
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer('list_tprivs.cgi', $text{'tprivs_return'},
	"", $text{'index_return'});

