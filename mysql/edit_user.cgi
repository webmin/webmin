#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing or creating a MySQL user

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} == 1 || &error($text{'perms_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'user_title1'}, "", "create_user");
	}
else {
	&ui_print_header(undef, $text{'user_title2'}, "", "edit_user");
	if ($in{'user'}) {
		$d = &execute_sql_safe($master_db,
				       "select * from user where user = ?",
				       $in{'user'});
		$u = $d->{'data'}->[0];
		}
	else {
		$d = &execute_sql_safe($master_db,
				       "select * from user order by user");
		$u = $d->{'data'}->[$in{'idx'}];
		}
	}

print "<form action=save_user.cgi>\n";
if ($in{'new'}) {
	print "<input type=hidden name=new value=1>\n";
	}
else {
	print "<input type=hidden name=olduser value='$u->[1]'>\n";
	print "<input type=hidden name=oldhost value='$u->[0]'>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'user_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'user_user'}</b></td> <td>\n";
printf "<input type=radio name=mysqluser_def value=1 %s> %s\n",
	$u->[1] ? '' : 'checked', $text{'user_all'};
printf "<input type=radio name=mysqluser_def value=0 %s>\n",
	$u->[1] ? 'checked' : '';
print "<input name=mysqluser size=10 value='$u->[1]'></td> </tr>\n";

print "<tr> <td><b>$text{'user_pass'}</b></td> <td>\n";
printf "<input type=radio name=mysqlpass_mode value=2 %s> %s\n",
	!$in{'new'} && !$u->[2] ? 'checked' : '', $text{'user_none'};
if (!$in{'new'}) {
	printf "<input type=radio name=mysqlpass_mode value=1 %s> %s\n",
		$u->[2] ? 'checked' : '', $text{'user_leave'};
	}
printf "<input type=radio name=mysqlpass_mode value=0 %s> %s\n",
	$in{'new'} ? 'checked' : '', $text{'user_set'};
print "<input name=mysqlpass type=password size=10></td> </tr>\n";

print "<tr> <td><b>$text{'user_host'}</b></td> <td>\n";
printf "<input type=radio name=host_def value=1 %s> %s\n",
	$u->[0] eq '%' || $u->[0] eq '' ? 'checked' : '', $text{'user_any'};
printf "<input type=radio name=host_def value=0 %s>\n",
	$u->[0] eq '%' || $u->[0] eq '' ? '' : 'checked';
printf "<input name=host size=20 value='%s'></td> </tr>\n",
	$u->[0] eq '%' ? '' : $u->[0];

print "<tr> <td valign=top><b>$text{'user_perms'}</b></td>\n";
print "<td><select name=perms multiple size=10>\n";
for($i=3; $i<=&user_priv_cols()+3-1; $i++) {
	printf "<option value=%d %s>%s\n",
		$i, $u->[$i] eq 'Y' ? 'selected' : '',
		$text{"user_priv$i"};
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'>\n";
if (!$in{'new'}) {
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer('list_users.cgi', $text{'users_return'},
	"", $text{'index_return'});

