#!/usr/local/bin/perl
# Update a manually edited map file

require './postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($err, %access, @files, %in, %text);
&ReadParseMime();
&error_setup($text{'manual_err'});
$access{'manual'} || &error($text{'manual_ecannot'});
@files = &get_maps_files(&get_real_value($in{'map_name'}));
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

# Save the data
$in{'data'} =~ s/\r//g;
my $filefh = "FILE";
&open_lock_tempfile($filefh, ">$in{'file'}");
&print_tempfile($filefh, $in{'data'});
&close_tempfile($filefh);

# Regenerate map
&regenerate_map_table($in{'map_name'});
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("manual", $in{'map_name'}.'s', $in{'file'});
&redirect_to_map_list($in{'map_name'});