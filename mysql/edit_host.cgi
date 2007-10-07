#!/usr/local/bin/perl
# edit_host.cgi
# Edit or create a host table record

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'host_title1'}, "");
	}
else {
	$d = &execute_sql_safe($master_db, "select * from host order by host");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	&ui_print_header(undef, $text{'host_title2'}, "");
	}

print "<form action=save_host.cgi>\n";
if ($in{'new'}) {
	print "<input type=hidden name=new value=1>\n";
	}
else {
	print "<input type=hidden name=oldhost value='$u->[0]'>\n";
	print "<input type=hidden name=olddb value='$u->[1]'>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'host_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'host_db'}</b></td>\n";
print "<td>",&select_db($u->[1]),"</td> </tr>\n";

print "<tr> <td><b>$text{'host_host'}</b></td> <td>\n";
printf "<input type=radio name=host_def value=1 %s> %s\n",
	$u->[0] eq '%' || $u->[0] eq '' ? 'checked' : '', $text{'host_any'};
printf "<input type=radio name=host_def value=0 %s>\n",
	$u->[0] eq '%' || $u->[0] eq '' ? '' : 'checked';
printf "<input name=host size=40 value='%s'></td> </tr>\n",
	$u->[0] eq '%' ? '' : $u->[0];

print "<tr> <td valign=top><b>$text{'host_perms'}</b></td>\n";
print "<td><select name=perms multiple size=8>\n";
for($i=2; $i<=&host_priv_cols()+2-1; $i++) {
	printf "<option value=%d %s>%s\n",
		$i, $u->[$i] eq 'Y' ? 'selected' : '',
		$text{"host_priv$i"};
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'>\n";
if (!$in{'new'}) {
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer('list_hosts.cgi', $text{'hosts_return'},
	"", $text{'index_return'});

