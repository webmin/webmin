#!/usr/local/bin/perl
# edit_auth.cgi
# Display authentication options and list of proxy users

require './squid-lib.pl';
$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ui_print_header(undef, $text{'eauth_header'}, "", undef, 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_auth.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'eauth_aopt'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

$v = &find_config("proxy_auth", $conf);
$authfile = $v->{'values'}->[0];
$authdom = $v->{'values'}->[1];
print "<tr> <td><b>$text{'eauth_puf'}</b></td> <td>\n";
printf "<input type=radio name=authfile_def value=1 %s> $text{'eauth_none'}&nbsp;\n",
	$authfile ? "" : "checked";
printf "<input type=radio name=authfile_def value=0 %s>\n",
	$authfile ? "checked" : "";
printf "<input name=authfile size=30 value=\"%s\">\n",
	$authfile ? $authfile : "";
print &file_chooser_button("authfile"),"</td> </tr>\n";

print "<tr>\n";
print "<td><b>$text{'eauth_nologin'}</b></td> <td>\n";
printf "<input type=radio name=authdom_def value=1 %s> $text{'eauth_none'}&nbsp;\n",
	$authdom ? "" : "checked";
printf "<input type=radio name=authdom_def value=0 %s>\n",
	$authdom ? "checked" : "";
printf "<input name=authdom size=20 value=\"%s\"></td>\n",
	$authdom ? $authdom : "";
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'eauth_buttsave'}></form>\n";

if ($authfile) {
	print "<hr>\n";
	print $text{'eauth_msgaccess'};
	print "\n<p>\n";
	@users = &list_auth_users($authfile);
	if (@users) {
		print "<a href=\"edit_user.cgi?new=1\">$text{'eauth_addpuser'}</a><br>\n";
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'eauth_pusers'}</b></td> </tr>\n";
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
		print "<b>$text{'eauth_nopusers'}</b> <p>\n";
		}
	print "<a href=\"edit_user.cgi?new=1\">$text{'eauth_addpuser'}</a><p>\n";
	}

&ui_print_footer("", $text{'eauth_return'});

