#!/usr/local/bin/perl
# delete_file.cgi
# Delete a downloaded package that is no longer needed

require './cpan-lib.pl';
&ReadParse();
$tmp_base = $gconfig{'tempdir'} || &default_webmin_temp_dir();
foreach $f (split(/\0/, $in{'file'})) {
	&is_under_directory($tmp_base, $f) || &error($text{'delete_efile'});
	unlink($f) if (!&is_readonly_mode());
	}
&redirect("");

