#!/usr/local/bin/perl
# Save one config file

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParseMime();
&error_setup($text{'manual_err'});

# Validate inputs
my @files = &list_all_config_files();
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});
$in{'manual'} =~ s/\r//g;
$in{'manual'} =~ /\S/ || &error($text{'manual_edata'});

# Write it out
my $fh = "FILE";
&open_lock_tempfile($fh, ">$in{'file'}");
&print_tempfile($fh, $in{'manual'});
&close_tempfile($fh);

&webmin_log("manual", undef, $in{'file'});
&redirect("");
