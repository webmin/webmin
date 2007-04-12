#!/usr/local/bin/perl
# edit_group.cgi
# Show a form for editing an existing groups

require './samba-lib.pl';
%access = &get_module_acl();
$access{'maint_groups'} || &error($text{'groups_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'gedit_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	@groups = &list_groups();
	$group = $groups[$in{'idx'}];
	}

print "<form action=save_group.cgi method=post>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'gedit_name'}</b></td>\n";
if ($in{'new'}) {
	print "<td><input name=name size=20></td>\n";
	}
else {
	print "<td><tt>$group->{'name'}</b></td>\n";
	}

print "<td><b>$text{'gedit_type'}</b></td>\n";
print "<td><select name=type>\n";
foreach $t ('l', 'd', 'b', 'u') {
	printf "<option value=%s %s>%s\n",
		$t, $group->{'type'} eq $t ? "selected" : "",
		$text{'groups_type_'.$t};
	$found++ if ($group->{'type'} eq $t);
	}
print "<option selected>$group->{'type'}\n" if (!$found && !$in{'new'});
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'gedit_unix'}</b></td> <td>\n";
if ($group->{'unix'} == -1) {
	printf "<input type=radio name=unix_def value=1 %s> %s\n",
		$group->{'unix'} == -1 ? "checked" : "", $text{'gedit_none'};
	printf "<input type=radio name=unix_def value=0 %s> %s\n",
		$group->{'unix'} == -1 ? "" :"checked", $text{'gedit_unixgr'};
	}
print &unix_group_input("unix",
		       $group->{'unix'} == -1 ? undef : $group->{'unix'});
print "</td>\n";

print "<td><b>$text{'gedit_desc'}</b></td>\n";
print "<td><input name=desc size=30 ",
      "value='$group->{'desc'}'></td> </tr>\n";

if ($in{'new'}) {
	print "<tr> <td><b>$text{'gedit_priv'}</b></td> <td colspan=3>\n";
	print "<input type=radio name=priv_def value=1 checked> $text{'gedit_none'}\n";
	print "<input type=radio name=priv_def value=0> $text{'gedit_set'}\n";
	print "<input name=priv size=50></td> </tr>\n";
	}
else {
	print "<tr> <td><b>$text{'gedit_sid'}</b></td>\n";
	print "<td colspan=3><tt>$group->{'sid'}</tt></td> </tr>\n";

	print "<tr> <td><b>$text{'gedit_priv'}</b></td>\n";
	print "<td colspan=3>",$group->{'priv'} || $text{'gedit_none'},"</td> </tr>\n";
	}

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right ><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("list_groups.cgi", $text{'groups_return'});

