#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing or creating a htpasswd user

require './htaccess-lib.pl';
&ReadParse();
@dirs = &list_directories();
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
&switch_user();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$user = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$users = $dir->[2] == 3 ? &list_digest_users($dir->[1])
				: &list_users($dir->[1]);
	$user = $users->[$in{'idx'}];
	}

print "<form action=save_user.cgi method=post>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=dir value='$in{'dir'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table cellpadding=3>\n";

# Username
print "<tr> <td><b>$text{'edit_user'}</b></td>\n";
printf "<td><input name=htuser size=20 value='%s'></td> </tr>\n",
	&html_escape($user->{'user'});

# User enabled?
print "<tr> <td><b>$text{'edit_enabled'}</b></td>\n";
printf "<td><input type=radio name=enabled value=1 %s> %s\n",
	$user->{'enabled'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=enabled value=0 %s> %s</td> </tr>\n",
	$user->{'enabled'} ? "" : "checked", $text{'no'};

# Password
print "<tr> <td valign=top><b>$text{'edit_pass'}</b></td> <td>\n";
if (!$in{'new'}) {
	print "<input type=radio name=htpass_def value=1 checked> ",
	      "$text{'edit_pass1'}<br>\n";
	print "<input type=radio name=htpass_def value=0> ",
	      "$text{'edit_pass0'}\n";
	}
print "<input type=password name=htpass size=20></td> </tr>\n";

if ($dir->[2] == 3) {
	# Digest realm
	print "<tr> <td><b>$text{'edit_dom'}</b></td>\n";
	printf "<td><input name=dom size=20 value='%s'></td> </tr>\n",
		&html_escape($user->{'dom'});
	}

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

