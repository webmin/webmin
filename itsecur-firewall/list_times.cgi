#!/usr/bin/perl
# list_times.cgi
# Display a list of time ranges that can be used in rules

require './itsecur-lib.pl';
&can_use_error("times");
&header($text{'times_title'}, "",
	undef, undef, undef, undef, &apply_button());
print &ui_hr();

my @times = &list_times();
my $edit = &can_edit("times");
my $link = ($edit ? &ui_link("edit_time.cgi?new=1",$text{'times_add'}) : ""); 
if (@times) {
	print $link;
    print &ui_columns_start([$text{'times_name'},$text{'times_hours'},$text{'times_days'}]);
    my @cols;
	foreach my $t (@times) {
        push(@cols, &ui_link("edit_time.cgi?idx=".$t->{'index'}, $t->{'name'}) );
        push(@cols, ($t->{'hours'} eq "*" ? $text{'times_all'} : $t->{'hours'}) );
        push(@cols, ($t->{'days'} eq "*" ? $text{'times_all'} : join(" ", map { $text{'sday_'.$_} } split(/,/, $t->{'days'})) ) );
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'times_none'}</b><p>\n";
	}
print $link;

print &ui_hr();
&footer("", $text{'index_return'});

