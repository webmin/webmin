#!/usr/bin/perl
# list_logs.cgi
# Real-time view of a log file

require './itsecur-lib.pl';
&can_use_error("logs");
$theme_no_table++;
$| = 1;
&header($text{'logs_title'}, "");
print "<hr>\n";

$log = $config{'log'} || &get_log_file();
print "<b>",&text('logs_viewing', "<tt>$log</tt>"),"</b><p>\n";
print "<applet code=LogViewer width=90% height=70%>\n";
print "<param name=url value='tail.cgi'>\n";
print "<param name=pause value=1>\n";
print "<param name=buttonlink value=download.cgi>\n";
print "<param name=buttonname value='$text{'logs_download'}'>\n";
if ($session_id) {
	print "<param name=session value=\"sid=$session_id\">\n";
	}
print "</applet>\n";
print "</form>\n";

print "<hr>\n";
&footer("", $text{'index_return'});

