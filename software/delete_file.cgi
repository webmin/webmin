#!/usr/local/bin/perl
# delete_file.cgi
# Delete a downloaded package that is no longer needed

require './software-lib.pl';
&ReadParse();
my $tmp_base = $gconfig{'tempdir'} || &default_webmin_temp_dir();
$in{'file'} =~ /^\Q$tmp_base\E\// || &error($text{'delete_efile'});
unlink($in{'file'});
&redirect("");

