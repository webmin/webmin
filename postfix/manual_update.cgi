#!/usr/local/bin/perl
# Update a manually edited config file

require './postfix-lib.pl';
&error_setup($text{'cmanual_err'});
$access{'manual'} || &error($text{'cmanual_ecannot'});
&ReadParseMime();

# Work out the file
@files = &get_all_config_files();
&indexof($in{'file'}, @files) >= 0 || &error($text{'cmanual_efile'});
$in{'data'} =~ s/\r//g;
if ($in{'file'} eq $files[0]) {
	$in{'data'} =~ /\S/ || &error($text{'cmanual_edata'});
	}

# Write to it
&open_lock_tempfile(DATA, ">$in{'file'}");
&print_tempfile(DATA, $in{'data'});
&close_tempfile(DATA);

&webmin_log("manual", undef, $in{'file'});
&redirect("");

