#!/usr/local/bin/perl
# Count up usage for selected directories

$no_acl_check = 1;
require './disk-usage-lib.pl';

$root = &build_root_usage_tree([ split(/\t+/, $config{'dirs'}) ]);
&save_usage_tree($root);

