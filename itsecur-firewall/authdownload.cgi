#!/usr/bin/perl
# authdownload.cgi
# Just dump log security file as text

require './itsecur-lib.pl';
&can_use_error("logs");
$log = $config{'authlog'} || &get_authlog_file();
print "Content-type: text/plain\n\n";
open(LOG, $log);
while(<LOG>) {
	print $_ if (!&is_log_line($_));
	}
close(LOG);

