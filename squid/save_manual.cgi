#!/usr/local/bin/perl
# Update a manually edited config file

require './squid-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});
$access{'manual'} || &error($text{'manual_ecannot'});
@files = &get_all_config_files();
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

# Save the data
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);

&webmin_log("manual", undef, $in{'file'});
&redirect("");