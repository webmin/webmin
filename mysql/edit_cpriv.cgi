#!/usr/local/bin/perl
# edit_cpriv.cgi
# Display a form for editing or creating new column permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});
if ($in{'table'}) {
	&ui_print_header(undef, $text{'cpriv_title1'}, "", "create_cpriv");
	($d, $t) = split(/\./, $in{'table'});
	}
else {
	$d = &execute_sql_safe($master_db, "select * from columns_priv order by table_name,column_name");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	$d = $u->[1]; $t = $u->[3];
	&ui_print_header(undef, $text{'cpriv_title2'}, "", "edit_cpriv");
	}

print "<form action=save_cpriv.cgi>\n";
if ($in{'table'}) {
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	}
else {
	print "<input type=hidden name=oldhost value='$u->[0]'>\n";
	print "<input type=hidden name=olddb value='$u->[1]'>\n";
	print "<input type=hidden name=olduser value='$u->[2]'>\n";
	print "<input type=hidden name=oldtable value='$u->[3]'>\n";
	print "<input type=hidden name=oldfield value='$u->[4]'>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'cpriv_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'cpriv_db'}</b></td>\n";
print "<td><tt>$d</tt></td> </tr>\n";

print "<tr> <td><b>$text{'cpriv_table'}</b></td>\n";
print "<td><tt>$t</tt></td> </tr>\n";

print "<tr> <td><b>$text{'cpriv_field'}</b></td>\n";
print "<td><select name=field>\n";
print "<option selected>\n" if ($in{'table'});
foreach $c (&table_structure($d, $t)) {
	printf "<option %s>%s\n",
		$u->[4] eq $c->{'field'} ? 'selected' : '',
		$c->{'field'};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'cpriv_user'}</b></td> <td>\n";
printf "<input type=radio name=user_def value=1 %s> %s\n",
	$u->[2] ? '' : 'checked', $text{'cpriv_anon'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$u->[2] ? 'checked' : '';
print "<input name=user size=20 value='$u->[2]'></td> </tr>\n";

print "<tr> <td><b>$text{'cpriv_host'}</b></td> <td>\n";
printf "<input type=radio name=host_def value=1 %s> %s\n",
	$u->[0] eq '%' || $u->[0] eq '' ? 'checked' : '', $text{'cpriv_any'};
printf "<input type=radio name=host_def value=0 %s>\n",
	$u->[0] eq '%' || $u->[0] eq '' ? '' : 'checked';
printf "<input name=host size=40 value='%s'></td> </tr>\n",
	$u->[0] eq '%' ? '' : $u->[0];

print "<tr> <td valign=top><b>$text{'cpriv_perms'}</b></td>\n";
print "<td><select multiple size=4 name=perms>\n";
foreach $p ('Select','Insert','Update','References') {
	printf "<option %s>%s\n",
		$u->[6] =~ /$p/i ? 'selected' : '', $p;
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'>\n";
if (!$in{'new'}) {
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer('list_cprivs.cgi', $text{'cprivs_return'},
	"", $text{'index_return'});

