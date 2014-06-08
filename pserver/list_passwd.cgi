#!/usr/local/bin/perl
# list_passwd.cgi
# Display all the cvs server users

require './pserver-lib.pl';
$access{'passwd'} || &error($text{'passwd_ecannot'});
&ui_print_header(undef, $text{'passwd_title'}, "");

print "$text{'passwd_desc'}<p>\n";
@passwd = &list_passwords();
@links = ( &ui_link("edit_passwd.cgi?new=1",$text{'passwd_add'}) );
if (@passwd) {
	print &ui_links_row(\@links);
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'passwd_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	$i = 0;
	foreach $p (@passwd) {
		print "<tr>\n" if ($i%4 == 0);
		print "<td width=25%>\n";
		print "<a href='edit_passwd.cgi?idx=$p->{'index'}'>";
		print $p->{'user'};
		if ($p->{'unix'}) {
			print "</a> ($p->{'unix'})</td>";
			}
		else {
			print "</a></td>\n";
			}
		print "</tr>\n" if ($i%4 == 3);
		$i++;
		}
	while($i++%4) { print "<td width=25%></td>\n"; }

	print "</table></td></tr></table>\n";
	}
else {
	print "<b>$text{'passwd_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

print &ui_hr();
print "<form action=save_sync.cgi>\n";
print "$text{'passwd_sync'}<p>\n";
printf "<input type=checkbox name=sync_create value=1 %s> %s<br>\n",
	$config{'sync_create'} ? "checked" : "", $text{'passwd_sync_create'};
print "&nbsp;" x 5,$text{'edit_unix'},"\n";
printf "<input type=radio name=sync_mode value=0 %s> %s\n",
	$config{'sync_user'} ? "" : "checked", $text{'edit_unixdef'};
printf "<input type=radio name=sync_mode value=1 %s>\n",
	$config{'sync_user'} ? "checked" : "";
print &unix_user_input("sync_user", $config{'sync_user'}),"<br>\n";
printf "<input type=checkbox name=sync_modify value=1 %s> %s<br>\n",
	$config{'sync_modify'} ? "checked" : "", $text{'passwd_sync_modify'};
printf "<input type=checkbox name=sync_delete value=1 %s> %s<p>\n",
	$config{'sync_delete'} ? "checked" : "", $text{'passwd_sync_delete'};

print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

