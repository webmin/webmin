#!/usr/local/bin/perl
# delete_file.cgi
# Delete a downloaded package that is no longer needed

require './software-lib.pl';
&ReadParse();
$in{'file'} =~ /^\/tmp\/.webmin\// || &error($text{'delete_efile'});
unlink($in{'file'});
&redirect("");

