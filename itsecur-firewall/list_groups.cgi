#!/usr/bin/perl
# list_groups.cgi
# Displays a list of host and network groups

require './itsecur-lib.pl';
&can_use_error("groups");
&header($text{'groups_title'}, "",
	undef, undef, undef, undef, &apply_button());
print &ui_hr();

my @groups = &list_groups();
my $edit = &can_edit("groups");

if (@groups) {
    print &ui_link("edit_group.cgi?new=1", $text{'groups_add'}) if ($edit);
    print &ui_columns_start([$text{'group_name'}, $text{'group_members'}]);
	foreach my $g (@groups) {
        my @cols_row;
        my $tx = "";
        my $link = &ui_link("edit_group.cgi?idx=".$g->{'index'}, $g->{'name'});
        push(@cols_row, ( $edit ? $link : $g->{'name'} ) );
		my @mems = @{$g->{'members'}};
		if (@mems > 5) {
            @mems = (@mems[0..4], "...");
        }
        push(@cols_row, join(" , ", map { &group_name($_) } @mems) );
        print &ui_columns_row(\@cols_row);
    }
	print &ui_columns_end();
	}
else {
	print "<b>$text{'groups_none'}</b><p>\n";
	}
print &ui_link("edit_group.cgi?new=1", $text{'groups_add'}) if ($edit);
print &ui_hr();
&footer("", $text{'index_return'});
