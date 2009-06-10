#!/usr/local/bin/perl
# edit_gsync.cgi
# Allow the user to edit auto updating of Samba groups by useradmin

require './samba-lib.pl';

$access{'maint_gsync'} || &error($text{'gsync_ecannot'});
&ui_print_header(undef, $text{'gsync_title'}, "");

&check_group_enabled($text{'gsync_cannot'});

print $text{'gsync_msg'}, "<p>\n";

print "<form action=save_gsync.cgi>\n";
printf "<input type=checkbox name=add value=1 %s>\n",
	$config{'gsync_add'} ? "checked" : "";
print "$text{'gsync_add'}\n";
print "<table>\n";
print "<tr> <td width=20></td> <td>$text{'gsync_type'}</td>\n";
print "<td><select name=type>\n";
foreach $t ('l', 'd', 'b', 'u') {
	printf "<option value=%s %s>%s\n",
		$t, $config{'gsync_type'} eq $t ? "selected" : "",
		$text{'groups_type_'.$t};
	}
print "</select></td> </tr>\n";
print "<tr> <td width=20></td> <td>$text{'gsync_priv'}</td>\n";
printf "<td><input name=priv size=40 value='%s'></td> </tr>\n",
	$config{'gsync_priv'};
print "</table><p>\n";

printf "<input type=checkbox name=change value=1 %s>\n",
	$config{'gsync_change'} ? "checked" : "";
print "$text{'gsync_chg'}<p>\n";

printf "<input type=checkbox name=delete value=1 %s>\n",
	$config{'gsync_delete'} ? "checked" : "";
print "$text{'gsync_del'}<p>\n";
print "<input type=submit value=\"", $text{'gsync_apply'}, "\"></form>\n";

&ui_print_footer("", $text{'index_sharelist'});

