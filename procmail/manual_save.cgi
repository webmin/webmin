#!/usr/local/bin/perl
# manual_save.cgi
# Write out the config file

require './procmail-lib.pl';
&ReadParseMime();

defined($in{'data'}) || &error($text{'manual_edata'});
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(FILE, ">$procmailrc");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);
&webmin_log("manual");
&redirect("");

