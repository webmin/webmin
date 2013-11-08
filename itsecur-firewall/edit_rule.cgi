#!/usr/bin/perl
# edit_rule.cgi
# Show a form for editing or creating a rule

require './itsecur-lib.pl';
&can_use_error("rules");
&ReadParse();
@rules = &list_rules();
if ($in{'new'}) {
	&header(defined($in{'insert'}) ? $text{'rule_title3'}
				       : $text{'rule_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	$rule = { 'enabled' => 1,
		  'action' => &default_action(),
		  'service' => '',
		  'source' => '',
		  'dest' => '',
		  'time' => '*',
		  'index' => scalar(@rules) };
	}
else {
	&header($text{'rule_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	$rule = $rules[$in{'idx'}];
	}
print "<hr>\n";

print "<form action=save_rule.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=insert value='$in{'insert'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'rule_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show comment
print "<tr> <td valign=top><b>$text{'rule_desc'}</b></td> <td colspan=2>\n";
printf "<input name=desc size=60 value='%s'></td> </tr>\n",
	$rule->{'desc'} eq "*" ? "" : $rule->{'desc'};

# Show source and destination
foreach $s ('source', 'dest') {
	$not = ($rule->{$s} =~ s/^!//g);
	$sm = $rule->{$s} eq '*' ? 0 :
	      $rule->{$s} =~ /^\@/ ? 2 :
	      $rule->{$s} =~ /^\%/ ? 3 : 1;

	# Any address options
	print "<tr> <td valign=top><b>",$text{'rule_'.$s},
	      "</b></td> <td colspan=2>\n";
	print "<table>\n";
	print "<tr><td colspan=2>";
	printf "<input type=radio name=${s}_mode value=0 %s> %s\n",
		$sm == 0 ? "checked" : "",
		$text{'rule_anywhere'};
	print "</td></tr>\n";

	# Specific host option
	print "<tr><td valign=top>";
	printf "<input type=radio name=${s}_mode value=1 %s> %s\n",
		$sm == 1 ? "checked" : "", $text{'rule_host'};
	print "</td><td>";
	printf "<input name=${s}_host size=30 value='%s'>\n",
		$sm == 1 ? $rule->{$s} : "";
	print "$text{'rule_named'}\n";
	print "<input name=${s}_name size=15><br>\n";
	print "<input type=checkbox name=${s}_resolv value=1> ",
	      "$text{'rule_resolv'}\n";
	print "</td></tr>\n";

	# Host group option
	local $gv;
	if ($rule->{$s} =~ /^\@(.*)$/) {
		$gv = $rule->{$s};
		$gv =~ s/(^|\s)@/$1/g;
		}
	$gi = &group_input("${s}_group", $gv, 0, 1);
	if ($gi || $sm == 2) {
		print "<tr><td valign=top>";
		printf "<input type=radio name=${s}_mode value=2 %s> %s\n",
			$sm == 2 ? "checked" : "", $text{'rule_group'};
		print "</td><td>";
		print $gi;
		print "</td></tr>\n";
		}

	# Interface option
	$ii = &iface_input("${s}_iface",
			   $rule->{$s} =~ /^\%(.*)$/ ? $1 : undef);
	if ($ii || $sm == 3) {
		print "<tr><td>";
		printf "<input type=radio name=${s}_mode value=3 %s> %s\n",
			$sm == 3 ? "checked" : "", $text{'rule_iface'};
		print "</td><td>";
		print $ii;
		print "</td></tr>\n";
		}

	print "</table>\n";
	print "</td> <td valign=top>\n";
	#printf "<input type=checkbox name=${s}_not value=1 %s> %s\n",
	#	$not ? "checked" : "", $text{'rule_not'};
	print "</td> </tr>\n";
	}

# Show service
$not = ($rule->{'service'} =~ s/^!//g);
print "<tr> <td valign=top><b>$text{'rule_service'}</b></td> <td>\n";
printf "<input type=radio name=service_mode value=0 %s> %s\n",
	$rule->{'service'} eq '*' ? "checked" : "", $text{'rule_anyserv'};
printf "<input type=radio name=service_mode value=1 %s> %s<br>\n",
	$rule->{'service'} eq '*' ? "" : "checked", $text{'rule_oneserv'};
print &service_input("service",
		     $rule->{'service'} eq '*' ? undef : $rule->{'service'},
		     0, 1);
print "</td> <td valign=top>\n";
#printf "<input type=checkbox name=snot value=1 %s> %s\n",
#	$not ? "checked" : "", $text{'rule_not'};
print "</td> </tr>\n";

# Show action upon match
print "<tr> <td valign=top><b>$text{'rule_action'}</b></td> <td>\n";
print &action_input("action", $rule->{'action'});
print "</td> <td>\n";
printf "<input type=checkbox name=log value=1 %s> %s\n",
	$rule->{'log'} ? 'checked' : '', $text{'rule_log'};
print "</td> </tr>\n";

# Show time that this rule applies
$inp = &time_input("time", $rule->{'time'} eq "*" ? undef : $rule->{'time'});
if ($inp) {
	print "<tr> <td valign=top><b>$text{'rule_time'}</b></td> <td>";
	printf "<input type=radio name=time_def value=1 %s> %s\n",
		$rule->{'time'} eq "*" ? "checked" : "", $text{'rule_anytime'};
	printf "<input type=radio name=time_def value=0 %s> %s\n",
		$rule->{'time'} eq "*" ? "" : "checked", $text{'rule_seltime'};
	print $inp;
	print "</td> </tr>\n";
	}
else {
	print "<input type=hidden name=time_def value=1>\n";
	}

# Show enabled flag
print "<tr> <td valign=top><b>$text{'rule_enabled'}</b></td> <td>\n";
printf "<input type=radio name=enabled value=1 %s> %s\n",
	$rule->{'enabled'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=enabled value=0 %s> %s\n",
	$rule->{'enabled'} ? "" : "checked", $text{'no'};
print "</td> </tr>\n";

# Show input for position of rule
print "<tr> <td><b>$text{'rule_atpos'}</b></td> <td>\n";
print "<select name=pos>\n";
foreach $br (@rules) {
	next if ($br eq $rule);
	if ($br->{'sep'}) {
		printf "<option value=%s %s>%s</option>\n",
			$br->{'index'},
			!$in{'new'} &&
			$rule->{'index'} == $br->{'index'}-1 ? "selected" : "",
			&text('rule_spos', $br->{'desc'});
		}
	else {
		printf "<option value=%s %s>%s</option>\n",
			$br->{'index'},
			!$in{'new'} &&
			$rule->{'index'} == $br->{'index'}-1 ? "selected" : "",
			&text('rule_pos', $br->{'num'},
			      &group_name($br->{'source'}),
			      &group_name($br->{'dest'}));
		}
	}
printf "<option value=%s %s>%s</option>\n",
	-1, $in{'new'} || $rule eq $rules[$#rules] ? "selected" : "",
	$text{'rule_end'};
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";
&can_edit_disable("rules");

print "<hr>\n";
&footer("list_rules.cgi", $text{'rules_return'});

