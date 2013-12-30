#!/usr/bin/perl
# edit_time.cgi
# Show a form for editing or creating a time range

require './itsecur-lib.pl';
&can_use_error("times");
&ReadParse();
if ($in{'new'}) {
	&header($text{'time_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	$time = { 'hours' => '*',
		  'days' => '*' };
	}
else {
	&header($text{'time_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	@times = &list_times();
	if (defined($in{'idx'})) {
		$time = $times[$in{'idx'}];
		}
	else {
		($time) = grep { $_->{'name'} eq $in{'name'} } @times;
		$in{'idx'} = $time->{'index'};
		}
	}
print &ui_hr();

print &ui_form_start("save_time.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});

print &ui_table_start($text{'time_header'}, undef, 2);

my @valign = ["valign=middle","valign=middle"];
# Show range name
print &ui_table_row($text{'time_name'}, &ui_textbox("name", $time->{'name'}, 20), undef, @valign );

# Show hour range
my ($from, $to) = $time->{'hours'} eq "*" ? ( ) : split(/\-/, $time->{'hours'});
print &ui_table_row($text{'time_hours'},
                &ui_radio("hours_def", ($time->{'hours'} eq "*" ? 1 : 0),[
                            [1, $text{'time_allday'}],[0,$text{'time_from'}]
                            ]).
                &ui_textbox("from", $from, 6)."&nbsp;".
                $text{'time_to'}."&nbsp;".&ui_textbox("to", $to, 6) 
        ,undef, @valign);

# Show days of week
my %days = map { $_, 1 } split(/,/, $time->{'days'});
my @sel;
for($i=0; $i<7; $i++) {
    push(@sel, [$i, $text{'day_'.$i}, ($days{$i} ? "selected" : "") ] );
}
print &ui_table_row($text{'time_days'},
                &ui_radio("days_def", ($time->{'days'} eq "*" ? 1 : 0),[
                            [1, $text{'time_allweek'}],[0,$text{'time_sel'}]
                            ])."<br>".
                &ui_select("days", undef, \@sel, 7, 1)
        ,undef, ["valign=top","valign=top"]);

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
&can_edit_disable("times");

print &ui_hr();
&footer("list_times.cgi", $text{'times_return'});

