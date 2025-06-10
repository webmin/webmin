#!/usr/local/bin/perl
# Swap two rules

require './ipfilter-lib.pl';
&ReadParse();
$rules = &get_config();

$rule1 = $rules->[$in{'idx'}];
if ($in{'up'}) {
	$rule2 = $rules->[$in{'idx'} - 1];
	}
else {
	$rule2 = $rules->[$in{'idx'} + 1];
	}
&lock_file($rule1->{'file'});
&swap_rules($rule1, $rule2);
&flush_file_lines();
&unlock_file($rule1->{'file'});
&copy_to_cluster();
&webmin_log("move", "rule", undef, $rule1);
&redirect("");

