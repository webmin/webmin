#!/usr/local/bin/perl
# Display a form for editing or adding a new CVS user

require './pserver-lib.pl';
$access{'passwd'} || &error($text{'passwd_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	@passwd = &list_passwords();
	$user = $passwd[$in{'idx'}];
	}

print "<form action=save_passwd.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'edit_user'}</b></td>\n";
printf "<td><input name=user size=15 value='%s'></td> </tr>\n",
	$user->{'user'};

print "<tr> <td><b>$text{'edit_pass'}</b></td>\n";
printf "<td><input type=radio name=pass_def value=2 %s> %s\n",
	$user->{'pass'} ? "" : "checked", $text{'edit_pass2'};
if ($in{'new'}) {
	printf "<input type=radio name=pass_def value=3> %s\n",
		$text{'edit_pass3'} if (&foreign_check("useradmin"));
	}
else {
	printf "<input type=radio name=pass_def value=1 %s> %s\n",
		$user->{'pass'} ? "checked" : "", $text{'edit_pass1'}
		if ($user->{'pass'});
	}
printf "<input type=radio name=pass_def value=0> %s\n",
	$text{'edit_pass0'};
print "<input type=password name=pass size=15></td> </tr>\n";

print "<tr> <td><b>$text{'edit_unix'}</b></td>\n";
printf "<td><input type=radio name=unix_def value=1 %s> %s\n",
	$user->{'unix'} ? "" : "checked", $text{'edit_unixdef'};
printf "<input type=radio name=unix_def value=0 %s>\n",
	$user->{'unix'} ? "checked" : "";
print &unix_user_input("unix", $user->{'unix'}),"</td> </tr>\n";

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer("list_passwd.cgi", $text{'passwd_return'},
	"", $text{'index_return'});

