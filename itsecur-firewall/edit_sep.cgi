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
print &ui_hr();

print &ui_form_start("save_sep.cgi", "post");
foreach my $th ('new', 'idx', 'insert') {
    print &ui_hidden($th, $in{'$th'} );
}

print &ui_table_start($text{'sep_header'}, undef, 2);
print &ui_table_row($text{'sep_desc'},
            &ui_textbox("desc", ( $rule->{'desc'} eq "*" ? "" : $rule->{'desc'} ),  60),
            undef, ["valign=middle","valign=middle"] );

# Show input for position of rule
my @sel;
foreach $br (@rules) {
	next if ($br eq $rule);
	if ($br->{'sep'}) {
        push(@sel, [ $br->{'index'}, &text('rule_spos', $br->{'desc'}),
            (!$in{'new'} && $rule->{'index'} == $br->{'index'}-1 ? "selected" : "") ] );
	} else {
        push(@sel, [ $br->{'index'},
            &text('rule_pos', $br->{'num'}, &group_name($br->{'source'}), &group_name($br->{'dest'})), 
            (!$in{'new'} && $rule->{'index'} == $br->{'index'}-1 ? "selected" : "") ] );
		}
	}
push(@sel, [ -1, $text{'rule_end'}, ($in{'new'} || $rule eq $rules[$#rules] ? "selected" : "") ] );
print &ui_table_row($text{'rule_atpos'}, &ui_select("pos", undef, \@sel, 1), undef, ["valign=middle","valign=middle"] );
print &ui_table_end();
print "<p>";
if ($in{'new'}) {
    print &ui_submit($text{'create'});
	}
else {
    print &ui_submit($text{'save'});
    print &ui_submit($text{'delete'}, "delete");
	}

print &ui_form_end();
&can_edit_disable("rules");

print &ui_hr();
&footer("list_rules.cgi", $text{'rules_return'});

