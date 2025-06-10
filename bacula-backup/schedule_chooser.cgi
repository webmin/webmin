#!/usr/local/bin/perl
# Show a popup window for selecting a Bacula schedule

require './bacula-backup-lib.pl';
&ReadParse();
&popup_header($text{'chooser_title'});

# Parse into month, day and hour parts
if ($in{'schedule'}) {
	$sched = &parse_schedule($in{'schedule'});
	}
else {
	$sched = { 'months_all' => 1,
		   'weekdays_all' => 1,
		   'weekdaynums_all' => 1,
		   'days_all' => 1,
		   'hour' => '00',
		   'minute' => '00',
		 };
	}
ref($sched) || &error($sched);
print &ui_form_start("schedule_select.cgi", "post");
@tds = ( "width=30%", "width=70%" );

# Show months section
@months = map { [ $_-1, $text{'month_'.$_} ] } (1 .. 12);
print &ui_table_start($text{'chooser_monthsh'}, "width=100%", 2);
print &ui_table_row($text{'chooser_months'},
	&ui_radio("months_all", $sched->{'months_all'} ? 1 : 0,
		  [ [ 1, $text{'chooser_all'} ],
		    [ 0, $text{'chooser_sel'} ] ])."<br>".
	&select_chooser("months", \@months, $sched->{'months'}),
	1, \@tds);
print &ui_table_end();

# Show days of month section
@days = map { [ $_, $_ ] } (1 .. 31);
print &ui_table_start($text{'chooser_daysh'}, "width=100%", 2);
print &ui_table_row($text{'chooser_days'},
	&ui_radio("days_all", $sched->{'days_all'} ? 1 : 0,
		  [ [ 1, $text{'chooser_all'} ],
		    [ 0, $text{'chooser_sel'} ] ])."<br>".
	&select_chooser("days", \@days, $sched->{'days'}, 8),
	1, \@tds);
print &ui_table_end();

# Show days of week section
@weekdays = map { [ $_, $text{'day_'.$_} ] } (0 .. 6);
@weekdaynums = map { [ $_, $text{'weekdaynum_'.$_} ] } (1 .. 5);
print &ui_table_start($text{'chooser_weekdaysh'}, "width=100%", 2);
print &ui_table_row($text{'chooser_weekdays'},
	&ui_radio("weekdays_all", $sched->{'weekdays_all'} ? 1 : 0,
		  [ [ 1, $text{'chooser_all'} ],
		    [ 0, $text{'chooser_sel'} ] ])."<br>".
	&select_chooser("weekdays", \@weekdays, $sched->{'weekdays'}),
	1, \@tds);
print &ui_table_row($text{'chooser_weekdaynums'},
	&ui_radio("weekdaynums_all", $sched->{'weekdaynums_all'} ? 1 : 0,
		  [ [ 1, $text{'chooser_all'} ],
		    [ 0, $text{'chooser_sel'} ] ])."<br>".
	&select_chooser("weekdaynums", \@weekdaynums,$sched->{'weekdaynums'},5),
	1, \@tds);
print &ui_table_end();

# Show time section
print &ui_table_start($text{'chooser_timeh'}, "width=100%", 2);
print &ui_table_row($text{'chooser_time'},
		    &ui_textbox("hour", $sched->{'hour'}, 3).":".
		    &ui_textbox("minute", $sched->{'minute'}, 3),
		    1, \@tds);
print &ui_table_end();

print &ui_form_end([ [ "ok", $text{'chooser_ok'} ] ]);

&popup_footer();

# select_chooser(name, &opts, &selected, [cols])
sub select_chooser
{
local ($name, $opts, $sel, $cols) = @_;
$cols ||= 4;
local %sel = map { $_, 1 } @$sel;
local $rv = "<table>\n";
for(my $i=0; $i<@$opts; $i++) {
	$rv .= "<tr>\n" if ($i%$cols == 0);
	$rv .= "<td>".&ui_checkbox($name, $opts->[$i]->[0], $opts->[$i]->[1],
				  $sel{$opts->[$i]->[0]})."</td>\n";
	$rv .= "</tr>\n" if ($i%$cols == $cols-1);
	}
$rv .= "</table>\n";
return $rv;
}
