#!/usr/local/bin/perl
# edit_user.cgi
# A form for adding or editing a squid user

require './squid-lib.pl';
$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'euser_header'}, "");
	}
else {
	&ui_print_header(undef, $text{'euser_header1'}, "");
	$conf = &get_config();
	@users = &list_auth_users(
			&find_config("proxy_auth", $conf)->{'values'}->[0]);
	%user = %{$users[$in{'index'}]};
	}

print "<form action=save_user.cgi>\n";
print "<input type=hidden name=index value=$in{'index'}>\n";
print "<input type=hidden name=new value=$in{'new'}>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'euser_pud'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'euser_u'}</b></td>\n";
print "<td><input name=user size=25 value=\"$user{'user'}\"></td> </tr>\n";

print "<tr> <td><b>$text{'euser_p'}</b></td> <td>\n";
if (%user) {
	print "<input type=radio name=pass_def value=1 checked> $text{'euser_u1'}\n";
	print "<input type=radio name=pass_def value=0>\n";
	print "<input name=pass size=20 type=password></td> </tr>\n";
	}
else {
	print "<input name=pass size=20 type=password></td> </tr>\n";
	}
print "</table></td></tr></table>\n";
if (%user) {
	print "<input type=submit value=$text{'buttsave'}>\n";
	print "<input type=submit name=delete value=$text{'buttdel'}>\n";
	}
else {
	print "<input type=submit value=$text{'euser_buttcreat'}>\n";
	}
print "</form>\n";

&ui_print_footer("edit_auth.cgi", $text{'euser_return'},
	"", $text{'index_return'});

