#!/usr/local/bin/perl
# edit_nauth.cgi
# Display a list of proxy users

require './squid-lib.pl';
if ($config{'crypt_conf'} == 1) {
	eval "use MD5";
	if ($@) {
        	&error(&text('eauth_nomd5', $module_name));
		}
	}

$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ui_print_header(undef, $text{'eauth_header'}, "", undef, 0, 0, 0, &restart_button());
$conf = &get_config();
$authfile = &get_auth_file($conf);

print &text('eauth_nmsgaccess', "<tt>$authfile</tt>"),"<p>\n";
@users = &list_auth_users($authfile);
if (@users) {
	print "<a href=\"edit_nuser.cgi?new=1\">$text{'eauth_addpuser'}</a><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'eauth_pusers'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	for($i=0; $i<@users; $i++) {
		local ($it, $unit) = $users[$i]->{'enabled'} ? ('', '') :
					('<i>', '</i>');
		print "<tr>\n" if ($i%4 == 0);
		print "<td width=25%><a href=\"edit_nuser.cgi?",
		      "index=$i\">$it$users[$i]->{'user'}$unit</a></td>\n";
		print "</tr>\n" if ($i%4 == 3);
		}
	while($i++%4) { print "<td width=25%></td>\n"; }
	print "</table></td></tr></table>\n";
	}
else {
	print "<b>$text{'eauth_nopusers'}</b> <p>\n";
	}
print "<a href=\"edit_nuser.cgi?new=1\">$text{'eauth_addpuser'}</a><p>\n";

&ui_print_footer("", $text{'eauth_return'});

