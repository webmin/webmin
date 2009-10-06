#!/usr/local/bin/perl
# Command-line script to enable status collection

$no_acl_check++;
require 'system-status-lib.pl';
$ARGV[0] eq 'none' || $ARGV[0] =~ /^[1-9][0-9]*$/ && $ARGV[0] <= 60 ||
	die "usage: enable-collection.pl none|<mins>";

$config{'collect_interval'} = $ARGV[0];
&save_module_config();
&setup_collectinfo_job();
