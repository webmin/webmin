#!/usr/local/bin/perl
# Save the config file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-tgtd-lib.pl';
our (%text, %config, %in);
&ReadParseMime();
&error_setup($text{'manual_err'});

# Validate inputs
my $conf = &get_tgtd_config();
my @files = ($config{'config_file'},
	     &unique(map { $_->{'file'} } @$conf));
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});
$in{'data'} =~ /\S/ || &error($text{'manual_edata'});

# Write out the file
my $fh = "CONFIG";
&open_lock_tempfile($fh, ">$in{'file'}");
&print_tempfile($fh, $in{'data'});
&close_tempfile($fh);

&webmin_log("manual", undef, $in{'file'});
&redirect("");
