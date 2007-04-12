#!/usr/local/bin/perl
# list_users.cgi
# Display MON users

require './mon-lib.pl';
&ui_print_header(undef, $text{'users_title'}, "");

$conf = &get_mon_config();
$authtype = &find_value("authtype", $conf);
if ($authtype ne 'userfile') {
	print "<p>",&text('users_etype', 'edit_global.cgi'),"<p>\n";
	}
else {
	@users = &list_users();
	$uf = &mon_users_file();
	if (@users) {
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>",&text('users_header', "<tt>$uf</tt>"),
		      "</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		for($i=0; $i<@users; $i++) {
			print "<tr>\n" if ($i%4 == 0);
			print "<td width=25%><a href=\"edit_user.cgi?",
			      "index=$i\">$users[$i]->{'user'}</a></td>\n";
			print "</tr>\n" if ($i%4 == 3);
			}
		while($i++%4) { print "<td width=25%></td>\n"; }
		print "</table></td></tr></table>\n";
		}
	else {
		print "<b>",&text('users_nousers', "<tt>$uf</tt>"),"</b> <p>\n";
		}
	print "<a href=\"edit_user.cgi?new=1\">$text{'users_add'}</a><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

