#!/usr/local/bin/perl
# Save a manually edited config file

require './postgresql-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});

# Write the file
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(MANUAL, ">$hba_conf_file");
&print_tempfile(MANUAL, $in{'data'});
&close_tempfile(MANUAL);

&webmin_log("manual");
&redirect("");
