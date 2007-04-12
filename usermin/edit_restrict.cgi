#!/usr/local/bin/perl
# edit_restrict.cgi
# Edit a user or group module restriction

require './usermin-lib.pl';
$access{'restrict'} || &error($text{'acl_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'restrict_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'restrict_edit'}, "");
	@usermods = &list_usermin_usermods();
	$um = $usermods[$in{'idx'}];
	}

print "<form action=save_restrict.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=all value='$in{'all'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'restrict_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'restrict_who2'}</b></td>\n";
$umode = $um->[0] eq "*" ? 2 :
	 $um->[0] =~ /^\@/ ? 1 :
	 $um->[0] =~ /^\// ? 3 :
			     0;

printf "<td><input type=radio name=umode value=2 %s> %s<br>\n",
	$umode == 2 ? "checked" : "", $text{'restrict_umode2'};

printf "<input type=radio name=umode value=0 %s> %s\n",
	$umode == 0 ? "checked" : "", $text{'restrict_umode0'};
printf "<input name=user size=13 value='%s'> %s<br>\n",
	$umode == 0 ? $um->[0] : "", &user_chooser_button("user");

printf "<input type=radio name=umode value=1 %s> %s\n",
	$umode == 1 ? "checked" : "", $text{'restrict_umode1'};
printf "<input name=group size=13 value='%s'> %s<br>\n",
	$umode == 1 ? substr($um->[0], 1) : "", &group_chooser_button("group");

if (&get_usermin_version() >= 1.031) {
	printf "<input type=radio name=umode value=3 %s> %s\n",
		$umode == 3 ? "checked" : "", $text{'restrict_umode3'};
	printf "<input name=file size=40 value='%s'> %s</td> </tr>\n",
		$umode == 3 ? $um->[0] : "", &file_chooser_button("file");
	}

&read_usermin_acl(\%acl);
print "<tr> <td valign=top><b>$text{'restrict_mods'}</b><br>",
      &text('restrict_modsdesc', "edit_acl.cgi"),"</td> <td>\n";
printf "<input type=radio name=mmode value=0 %s> %s\n",
	$um->[1] eq "" ? "checked" : "", $text{'restrict_mmode0'};
printf "<input type=radio name=mmode value=1 %s> %s\n",
	$um->[1] eq "+" ? "checked" : "", $text{'restrict_mmode1'};
printf "<input type=radio name=mmode value=2 %s> %s<br>\n",
	$um->[1] eq "-" ? "checked" : "", $text{'restrict_mmode2'};
@mods = &list_modules();
print "<table>\n";
foreach $m (@mods) {
	print "<tr>\n" if ($i % 3 == 0);
	printf "<td width=33%%><input type=checkbox name=mod value=%s %s> %s</td>\n",
		$m->{'dir'}, &indexof($m->{'dir'}, @{$um->[2]}) >= 0 ?
				'checked' : '',
		$acl{"user",$m->{'dir'}} ? $m->{'desc'} : "<font color=#ff0000>$m->{'desc'}</font>";
	print "</tr>\n" if ($i % 3 == 2);
	$i++;
	}
print "</table>\n";
print &select_all_link("mod", 0),"\n";
print &select_invert_link("mod", 0),"\n";
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("list_restrict.cgi", $text{'restrict_return'});

