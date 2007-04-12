#!/usr/local/bin/perl
# edit_authuser.cgi
# Display a form for editing a user from a text file

require './apache-lib.pl';
require './auth-lib.pl';

&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error(&text('authu_ecannot', $in{'file'}));
$desc = &text('authu_header', "<tt>$in{'file'}</tt>");
if (defined($in{'user'})) {
	# editing an existing user
	&ui_print_header($desc, $text{'authu_edit'}, "");
	$u = &get_authuser($in{'file'}, $in{'user'});
	$user = $u->{'user'};
	$pass = $u->{'pass'};
	$new = 0;
	}
else {
	# creating a new user
	&ui_print_header($desc, $text{'authu_create'}, "");
	$new = 1;
	}

print "<form method=post action=save_authuser.cgi>\n";
print "<input type=hidden name=file value=\"$in{'file'}\">\n";
print "<input type=hidden name=url value=\"$in{'url'}\">\n";
if (!$new) { print "<input type=hidden name=olduser value=$in{'user'}>\n"; }

print "<table border>\n";
printf "<tr $tb> <td><b>%s</b></td> </tr>\n",
	$new ? $text{'authu_create'} : $text{'authu_edit'};
print "<tr $cb> <td><table>\n";

print "<tr $cb> <td><b>$text{'authu_user'}</b></td>\n";
print "<td><input name=user size=20 value=\"$user\"></td> </tr>\n";
print "<tr $cb> <td><b>$text{'authu_pass'}</b></td>\n";
printf "<td><input name=mode type=radio value=1 %s> $text{'authu_enc'}\n",
	$new ? '' : 'checked';
print "<input name=enc size=15 value='$pass'>\n";
printf "<input name=mode type=radio value=0 %s> $text{'authu_plain'}\n",
	$new ? 'checked' : '';
print "<input name=pass size=15></td> </tr>\n";

print "<tr> <td colspan=2 align=right>\n";
print "<input type=submit value=\"$text{'save'}\">\n";
print "<input type=submit value=\"$text{'delete'}\" name=delete>\n"
	if (!$new);
print "</td> </tr></table></td></tr></table>\n";
print "</form>\n";

&ui_print_footer($in{'url'}, $text{'authu_return'});

