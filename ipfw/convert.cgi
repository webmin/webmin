#!/usr/local/bin/perl
# Save active firewall rules to a file

require './ipfw-lib.pl';
&ReadParse();
&error_setup($text{'convert_err'});
&lock_file($ipfw_file);
&system_logged("$config{'ipfw'} list > $ipfw_file");
&unlock_file($ipfw_file);
&webmin_log("convert");
&redirect("");

