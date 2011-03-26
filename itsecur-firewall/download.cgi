#!/usr/bin/perl
# download.cgi
# Just dump log file as text

require './itsecur-lib.pl';
&can_use_error("logs");
$log = $config{'log'} || &get_log_file();
print "Content-type: text/plain\n\n";
open(LOG, $log);
while(<LOG>) {
	print $_ if (&is_log_line($_));
	}
close(LOG);

