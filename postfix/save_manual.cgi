#!/usr/local/bin/perl
# Update a manually edited map file

require './postfix-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});
$access{'manual'} || &error($text{'manual_ecannot'});
@files = &get_maps_files(&get_real_value($in{'map_name'}));
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

# Save the data
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);

# Regenerate map
&regenerate_map_table($in{'map_name'});
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("manual", $in{'map_name'}.'s', $in{'file'});
&redirect_to_map_list($in{'map_name'});