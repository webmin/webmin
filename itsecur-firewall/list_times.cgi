#!/usr/bin/perl
# list_times.cgi
# Display a list of time ranges that can be used in rules

require './itsecur-lib.pl';
&can_use_error("times");
&header($text{'times_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

@times = &list_times();
$edit = &can_edit("times");
if (@times) {
	print "<a href='edit_time.cgi?new=1'>$text{'times_add'}</a><br>\n"
		if ($edit);
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'times_name'}</b></td> ",
	      "<td><b>$text{'times_hours'}</b></td> ",
	      "<td><b>$text{'times_days'}</b></td> </tr>\n";
	foreach $t (@times) {
		print "<tr $cb>\n";
		print "<td><a href='edit_time.cgi?idx=$t->{'index'}'>",
		      "$t->{'name'}</a></td>\n";
		print "<td>",$t->{'hours'} eq "*" ? $text{'times_all'} :
						    $t->{'hours'},"</td>\n";
		print "<td>",$t->{'days'} eq "*" ? $text{'times_all'} :
			join(" ", map { $text{'sday_'.$_} } split(/,/, $t->{'days'})),"</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'times_none'}</b><p>\n";
	}
print "<a href='edit_time.cgi?new=1'>$text{'times_add'}</a><p>\n"
	if ($edit);

print "<hr>\n";
&footer("", $text{'index_return'});

