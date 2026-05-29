#!/usr/local/bin/perl
# delete_file.cgi
# Delete a downloaded package that is no longer needed

require './software-lib.pl';
&ReadParse();
my $tmp_base = $gconfig{'tempdir'} || &default_webmin_temp_dir();
&is_under_directory($tmp_base, $in{'file'}) || &error($text{'delete_efile'});
unlink($in{'file'}) if (!&is_readonly_mode());
&redirect("");

