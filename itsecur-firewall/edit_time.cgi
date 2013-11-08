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
print "<hr>\n";

print "<form action=save_time.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'time_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show range name
print "<tr> <td><b>$text{'time_name'}</b></td>\n";
printf "<td><input name=name size=20 value='%s'></td> </tr>\n",
	$time->{'name'};

# Show hour range
print "<tr> <td><b>$text{'time_hours'}</b></td> <td>\n";
printf "<input type=radio name=hours_def value=1 %s> %s\n",
	$time->{'hours'} eq "*" ? "checked" : "", $text{'time_allday'};
printf "<input type=radio name=hours_def value=0 %s>\n",
	$time->{'hours'} eq "*" ? "" : "checked";
($from, $to) = $time->{'hours'} eq "*" ? ( ) : split(/\-/, $time->{'hours'});
printf "%s <input name=from size=6 value='%s'>\n",
	$text{'time_from'}, $from;
printf "%s <input name=to size=6 value='%s'></td> </tr>\n",
	$text{'time_to'}, $to;

# Show days of week
print "<tr> <td valign=top><b>$text{'time_days'}</b></td> <td>\n";
printf "<input type=radio name=days_def value=1 %s> %s\n",
	$time->{'days'} eq "*" ? "checked" : "", $text{'time_allweek'};
printf "<input type=radio name=days_def value=0 %s> %s<br>\n",
	$time->{'days'} eq "*" ? "" : "checked", $text{'time_sel'};
%days = map { $_, 1 } split(/,/, $time->{'days'});
print "<select name=days size=7 multiple>\n";
for($i=0; $i<7; $i++) {
	printf "<option value=%s %s>%s</option>\n",
		$i, $days{$i} ? "selected" : "", $text{'day_'.$i};
	}
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
&can_edit_disable("times");

print "<hr>\n";
&footer("list_times.cgi", $text{'times_return'});

