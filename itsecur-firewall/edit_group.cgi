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
print &ui_hr();

print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("from", $in{'from'});
print &ui_table_start($text{'group_header'}, undef, 2);

print &ui_table_row($text{'group_name'},
                    &ui_textbox("name", $group->{'name'}, 20),
                    undef, ["valign=middle","valign=middle"] );

my $tx = "";
$tx .= &ui_columns_start(undef);
$i = 0;
foreach $m (( grep { !/\!?\@/ } @{$group->{'members'}} ),
	    $blank, $blank, $blank, $blank, $blank, $blank) {
	$neg = ($m =~ s/^\!//);
    my @cols;
	push(@cols, &ui_textbox("member_".$i, $m, 40) );
	push(@cols, &ui_checkbox("neg_".$i, "!", $text{'group_neg'}, ($neg ? 1 : 0 ) ) );
    $tx .= &ui_columns_row(\@cols, ["valign=middle","valign=middle"]);
	$i++;
	}
$tx .= &ui_columns_row([ &ui_checkbox("resolv", 1, $text{'group_resolv'}) ], ["colspan=2"]);
$tx .= ui_columns_end();

print &ui_table_row($text{'group_members'}, $tx);

# Show member groups
$i = 0;
$tx = &ui_columns_start(undef);
foreach $m (( grep { /\!?\@/ } @{$group->{'members'}} ),
	    $blank, $blank, $blank, $blank, $blank, $blank) {
	$neg = ($m =~ s/^\!//);
	$m =~ s/^\@//;
	$tx .= &ui_columns_row([&group_input("group_$i", $m, 1)]);
	$i++;
	}
$tx .= ui_columns_end();
print &ui_table_row($text{'group_members2'}, $tx);

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
&can_edit_disable("groups");

print &ui_hr();
$from = $in{'from'} || "groups";
&footer("list_${from}.cgi", $text{$from.'_return'});

