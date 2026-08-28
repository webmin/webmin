#!/usr/local/bin/perl
# Close the current binary log and start writing a new one

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'binlogs_ecannot'});
&error_setup($text{'binlogs_rotateerr'});
&ReadParse();

my ($curfile) = &get_binary_log_status();
$curfile || &error($text{'binlogs_epurgeoff'});
&rotate_binary_logs();
&webmin_log("flushbinlogs");
&redirect("edit_binlogs.cgi");
