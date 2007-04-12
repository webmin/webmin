#!/usr/local/bin/perl
# move.cgi
# Swap two rules

require './ipfw-lib.pl';
&ReadParse();
$rules = &get_config();

$rule1 = $rules->[$in{'idx'}];
$rule2 = $rules->[$in{'up'} ? $in{'idx'}-1 : $in{'idx'}+1];
($rules->[$rule1->{'index'}], $rules->[$rule2->{'index'}]) =
	($rules->[$rule2->{'index'}], $rules->[$rule1->{'index'}]);
($rule1->{'num'}, $rule2->{'num'}) =
	($rule2->{'num'}, $rule1->{'num'});
&lock_file($ipfw_file);
&save_config($rules);
&unlock_file($ipfw_file);
&copy_to_cluster();
&webmin_log("move", "rule", $rule1->{'action'}, $rule1);
&redirect("");

