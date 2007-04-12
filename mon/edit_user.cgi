#!/usr/local/bin/perl
# edit_user.cgi
# A form for adding or editing a MON user

require './mon-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'user_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'user_edit'}, "");
	@users = &list_users();
	%user = %{$users[$in{'index'}]};
	}

print "<form action=save_user.cgi>\n";
print "<input type=hidden name=index value=$in{'index'}>\n";
print "<input type=hidden name=new value=$in{'new'}>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'user_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'user_user'}</b></td>\n";
print "<td><input name=user size=25 value=\"$user{'user'}\"></td> </tr>\n";

print "<tr> <td><b>$text{'user_pass'}</b></td> <td>\n";
if (%user) {
	print "<input type=radio name=pass_def value=1 checked> $text{'user_leave'}\n";
	print "<input type=radio name=pass_def value=0>\n";
	print "<input name=pass size=20 type=password></td> </tr>\n";
	}
else {
	print "<input name=pass size=20 type=password></td> </tr>\n";
	}
print "</table></td></tr></table>\n";
if (%user) {
	print "<input type=submit value=\"$text{'save'}\">\n";
	print "<input type=submit name=delete value=\"$text{'delete'}\">\n";
	}
else {
	print "<input type=submit value=\"$text{'create'}\">\n";
	}
print "</form>\n";

&ui_print_footer("list_users.cgi", $text{'users_return'},
	"", $text{'index_return'});

