#!/usr/local/bin/perl
# log_viewer.cgi
# Display logfile

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'log_viewer_title'}, "");

# get logfile path
if (defined($in{'logfile'})) {
	$logfile = $in{'logfile'};
	# remove quotes
	$logfile =~ /\'([^\']*)\'/;
	$logfile = $1;
} else {
	&error("No logfile name supplied to logfile viewer!");
	}
$numlines = 40;
if (defined($in{'numlines'})) {
	$numlines = $in{'numlines'};
	if ($numlines ne "all") {
		$numlines = int($numlines);
		}
}

if ($numlines eq "all") {
	$newnumlines = &backquote_logged("/usr/bin/wc -l $logfile");
	if ($newnumlines =~ /([0-9]+)\s+$logfile/) {
		$numlines = $1;
		}
	}
$data = &backquote_logged("/usr/bin/tail -$numlines $logfile");
print "<h2>";
&text_and_whats_this("log_viewer_detail");
print " : $logfile</h2>\n";

print "<form method=\"POST\" action=\"log_viewer.cgi?logfile='$logfile'\">\n";

# show selection for number of logfile lines to display
print "<p>$text{'log_viewer_show_last'}&nbsp;:&nbsp;\n";
&print_selection("numlines", $numlines, \@logfile_numlines_values);
print "$text{'log_viewer_num_lines'}&nbsp;:&nbsp;$logfile&nbsp;";
print
 "<input type=submit name=\"submit\" value=\"$text{'log_viewer_submit'}\">";
print "</p></form>\n";

print &ui_hr();

print "<p><pre>";
print "$data";
print "</pre></p>\n";

&ui_print_footer("index.cgi", $text{'index'});

