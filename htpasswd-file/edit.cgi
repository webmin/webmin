#!/usr/local/bin/perl
# edit.cgi
# Display a form for editing or creating a htpasswd user

require './htpasswd-file-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$user = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	if (!$access{'single'}) {
		$users = &list_users();
		$user = $users->[$in{'idx'}];
		}
	}

print "<form action=save.cgi method=post>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table cellpadding=3>\n";

if ($access{'single'}) {
	print "<tr> <td><b>$text{'edit_single'}</b></td>\n";
	print "<td><input name=user size=20></td> </tr>\n";
	}
else {
	print "<tr> <td><b>$text{'edit_user'}</b></td>\n";
	if ($access{'rename'} || $in{'new'}) {
		printf "<td><input name=user size=20 value='%s'></td> </tr>\n",
			&html_escape($user->{'user'});
		}
	}

if ($access{'enable'}) {
	print "<tr> <td><b>$text{'edit_enabled'}</b></td>\n";
	printf "<td><input type=radio name=enabled value=1 %s> %s\n",
		$user->{'enabled'} ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=enabled value=0 %s> %s</td> </tr>\n",
		$user->{'enabled'} ? "" : "checked", $text{'no'};
	}

print "<tr> <td valign=top><b>$text{'edit_pass'}</b></td> <td>\n";
if (!$in{'new'}) {
	if (!$access{'single'}) {
		print "<input type=radio name=pass_def value=1 checked> ",
		      "$text{'edit_pass1'}<br>\n";
		print "<input type=radio name=pass_def value=0>\n";
		}
	if ($access{'repeat'}) {
		print "$text{'edit_passfrom'}\n";
		print "<input type=password name=oldpass size=20>\n";
		print "$text{'edit_passto'}\n";
		}
	else {
		print "$text{'edit_pass0'}\n";
		}
	}
print "<input type=password name=pass size=20></td> </tr>\n";

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n"
		if ($access{'delete'} && !$access{'single'});
	}
print "</form>\n";

if ($access{'single'}) {
	&ui_print_footer("/", $text{'index'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}


