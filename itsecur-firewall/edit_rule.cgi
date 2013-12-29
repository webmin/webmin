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
print &ui_hr();
print &ui_form_start("save_rule.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("insert", $in{'insert'});
print &ui_table_start($text{'rule_header'}, undef, 2);

# Show comment
print &ui_table_row($text{'rule_desc'},
                    &ui_textbox("desc", ($rule->{'desc'} eq "*" ? "" : $rule->{'desc'}), 60),undef,
                    ["valign=middle","valign=middle"]);
    
# Show source and destination
foreach $s ('source', 'dest') {
	$not = ($rule->{$s} =~ s/^!//g);
	$sm = $rule->{$s} eq '*' ? 0 :
	      $rule->{$s} =~ /^\@/ ? 2 :
	      $rule->{$s} =~ /^\%/ ? 3 : 1;

	# Any address options
    print &ui_table_row($text{'rule_'.$s},
            &ui_oneradio(${s}."_mode", 0, $text{'rule_anywhere'}, ($sm == 0 ? 1 : 0 ))."<br>".

	# Specific host option
            &ui_oneradio(${s}."_mode", 1, $text{'rule_host'}, ($sm == 1 ? 1 : 0))."&nbsp;".
            &ui_textbox(${s}."_host", ($sm == 1 ? $rule->{$s} : ""), 30)."&nbsp;".$text{'rule_named'}."&nbsp;".
            &ui_textbox(${s}."_name", undef, 15)."<br>".
            &ui_checkbox(${s}."_resolv", 1, $text{'rule_resolv'},undef,"style=margin-left:15px;"), undef, ["valign=top","valign=middle"] );

	# Host group option
	local $gv;
	if ($rule->{$s} =~ /^\@(.*)$/) {
		$gv = $rule->{$s};
		$gv =~ s/(^|\s)@/$1/g;
		}
	$gi = &group_input("${s}_group", $gv, 0, 1);
	if ($gi || $sm == 2) {
        print &ui_table_row("&nbsp;",
                "<table style='margin:0;padding:0;'><tr><td style='margin:0;padding:0;' valign=top>".&ui_oneradio(${s}."_mode", 2, $text{'rule_group'}, ($sm == 2 ? 1 : 0))."</td><td valign=top>".
                $gi."</tr></table>",undef,["valign=top","valign=top"]);
		}

	# Interface option
	$ii = &iface_input("${s}_iface",
			   $rule->{$s} =~ /^\%(.*)$/ ? $1 : undef);
	if ($ii || $sm == 3) {
        print &ui_table_row("&nbsp;",
                &ui_oneradio(${s}."_mode", 3, $text{'rule_iface'}, ($sm == 3 ? 1 : 0))."&nbsp;".
                $ii);
		}
}

# Show service
$not = ($rule->{'service'} =~ s/^!//g);
print &ui_table_row($text{'rule_service'},
            &ui_radio("service_mode", ( $rule->{'service'} eq '*' ? 0 : 1 ),
                        [ [ 0, $text{'rule_anyserv'} ], [1, $text{'rule_oneserv'}] ]) );
print &ui_table_row("&nbsp;",
            &service_input("service", $rule->{'service'} eq '*' ? undef : $rule->{'service'}, 0, 1) );

            
# Show action upon match
print &ui_table_row($text{'rule_action'},
                &action_input("action", $rule->{'action'}).
                "&nbsp;&nbsp;".&ui_checkbox("log", 1, $text{'rule_log'}, ($rule->{'log'} ? 1 : 0) )
            ,undef, ["valign=middle","valign=middle"]);


# Show time that this rule applies
$inp = &time_input("time", $rule->{'time'} eq "*" ? undef : $rule->{'time'});
if ($inp) {
    print &ui_table_row($text{'rule_time'},
                &ui_radio("time_def", ( $rule->{'time'} eq '*' ? 1 : 0 ),
                        [ [ 1, $text{'rule_anytime'} ], [0, $text{'rule_seltime'}] ]).$inp);
	}
else {
    print &ui_hidden("time_def",1);
	}

# Show enabled flag
print &ui_table_row($text{'rule_enabled'},
                &ui_yesno_radio("enabled", ( $rule->{'enabled'} ? 1 : 0 ), 1, 0) );

# Show input for position of rule
my @sel;
foreach $br (@rules) {
	next if ($br eq $rule);
	if ($br->{'sep'}) {
        push(@sel, [ $br->{'index'}, &text('rule_spos', $br->{'desc'}),
                    (!$in{'new'} && $rule->{'index'} == $br->{'index'}-1 ? "selected" : "") ] );
	} else {
        push(@sel, [ $br->{'index'}, &text('rule_pos', $br->{'num'}, &group_name($br->{'source'}), &group_name($br->{'dest'})),
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

print &ui_form_end(undef,undef,1);

&can_edit_disable("rules");

print &ui_hr();
&footer("list_rules.cgi", $text{'rules_return'});

