#!/usr/local/bin/perl
# Command-line script to enable status collection

use strict;
use warnings;
our (%config);
require './system-status-lib.pl';
my $zero = @ARGV ? $ARGV[0] : '';
$zero eq 'none' || $zero =~ /^[1-9][0-9]*$/ && $zero <= 60 ||
	die "usage: enable-collection.pl none|<mins>";

$config{'collect_interval'} = $ARGV[0];
&save_module_config();
&setup_collectinfo_job();
