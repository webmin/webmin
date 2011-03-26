#!/usr/bin/perl
# edit_group.cgi
# Show a form for editing or creating a group of hosts or nets

require './itsecur-lib.pl';
&can_use_error("groups");
&ReadParse();
if ($in{'new'}) {
	&header($text{'group_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	}
else {
	&header($text{'group_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	@groups = &list_groups();
	if (defined($in{'idx'})) {
		$group = $groups[$in{'idx'}];
		}
	else {
		($group) = grep { $_->{'name'} eq $in{'name'} } @groups;
		$in{'idx'} = $group->{'index'};
		}
	}
print "<hr>\n";

print "<form action=save_group.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=from value='$in{'from'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'group_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'group_name'}</b></td>\n";
printf "<td><input name=name size=20 value='%s'></td> </tr>\n",
	$group->{'name'};

print "<tr> <td valign=top><b>$text{'group_members'}</b></td>\n";
print "<td><table>\n";
$i = 0;
foreach $m (( grep { !/\!?\@/ } @{$group->{'members'}} ),
	    $blank, $blank, $blank, $blank, $blank, $blank) {
	$neg = ($m =~ s/^\!//);
	print "<input name=member_$i size=40 value='$m'>\n";
	print "<input type=checkbox name=neg_$i value=! ",
	      $neg ? "checked" : "","> $text{'group_neg'}<br>\n";
	$i++;
	}
print "</table>\n";
print "<input type=checkbox name=resolv value=1> $text{'group_resolv'}\n";
print "</td> </tr>\n";

# Show member groups
print "<tr> <td valign=top><b>$text{'group_members2'}</b></td>\n";
print "<td><table>\n";
$i = 0;
foreach $m (( grep { /\!?\@/ } @{$group->{'members'}} ),
	    $blank, $blank, $blank, $blank, $blank, $blank) {
	$neg = ($m =~ s/^\!//);
	$m =~ s/^\@//;
	print "<tr> <td>\n";
	print &group_input("group_$i", $m, 1);
	print "</td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";
&can_edit_disable("groups");

print "<hr>\n";
$from = $in{'from'} || "groups";
&footer("list_${from}.cgi", $text{$from.'_return'});

