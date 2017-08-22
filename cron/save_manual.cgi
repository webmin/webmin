#!/usr/local/bin/perl
# Save a manually edited cron job

require './cron-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});
$access{'mode'} == 0 || &error($text{'manual_ecannot'});

# Validate the file and update it
my @files = &list_cron_files();
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});
$in{'data'} =~ s/\r//g;
$in{'data'} .= "\n" if ($in{'data'} !~ /\n$/);
&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);

&webmin_log("manual", undef, $in{'file'});
&redirect("index.cgi?search=".&urlize($in{'search'}));
