#!/usr/local/bin/perl
# Save the config file

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %config, %in);
&ReadParseMime();
&error_setup($text{'manual_err'});

$in{'data'} =~ /\S/ || &error($text{'manual_edata'});
my $fh = "CONFIG";
&open_lock_tempfile($fh, ">$config{'targets_file'}");
&print_tempfile($fh, $in{'data'});
&close_tempfile($fh);

&webmin_log("manual");
&redirect("");
