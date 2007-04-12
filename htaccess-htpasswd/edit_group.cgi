#!/usr/local/bin/perl
# Display a form for editing or creating a htgroup entry

require './htaccess-lib.pl';
&ReadParse();
@dirs = &list_directories();
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
&switch_user();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'gedit_title1'}, "");
	$group = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	$groups = &list_groups($dir->[4]);
	$group = $groups->[$in{'idx'}];
	}

print "<form action=save_group.cgi method=post>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=dir value='$in{'dir'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'gedit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table cellpadding=3>\n";

print "<tr> <td><b>$text{'gedit_group'}</b></td>\n";
printf "<td><input name=group size=20 value='%s'></td> </tr>\n",
	&html_escape($group->{'group'});

print "<tr> <td><b>$text{'edit_enabled'}</b></td>\n";
printf "<td><input type=radio name=enabled value=1 %s> %s\n",
	$group->{'enabled'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=enabled value=0 %s> %s</td> </tr>\n",
	$group->{'enabled'} ? "" : "checked", $text{'no'};

print "<tr> <td valign=top><b>$text{'gedit_members'}</b></td>\n";
print "<td><textarea name=members rows=5 cols=40 wrap=on>",
	join("\n", @{$group->{'members'}}),"</textarea></td> </tr>\n";

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

