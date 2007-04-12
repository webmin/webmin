#!/usr/local/bin/perl

chdir("..");
require './webmin-lib.pl';
&header("smeg", "");

print "module = $module_name<br>\n";
print "module root = $module_root_directory<br>\n";
print "module config = $module_config_directory<br>\n";

&footer("", $text{'index_return'});

