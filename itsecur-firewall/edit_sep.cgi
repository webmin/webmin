#!/usr/bin/perl
# Show a form for editing or creating a rule list section separator

require './itsecur-lib.pl';
&can_use_error("rules");
&ReadParse();
@rules = &list_rules();
if ($in{'new'}) {
	&header(defined($in{'insert'}) ? $text{'sep_title3'}
				       : $text{'sep_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	$rule = { 'index' => scalar(@rules) };
	}
else {
	&header($text{'sep_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	$rule = $rules[$in{'idx'}];
	}
print "<hr>\n";

print "<form action=save_sep.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=insert value='$in{'insert'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'sep_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show separator title
print "<tr> <td valign=top><b>$text{'sep_desc'}</b></td> <td>\n";
printf "<input name=desc size=60 value='%s'></td> </tr>\n",
	$rule->{'desc'} eq "*" ? "" : $rule->{'desc'};

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

