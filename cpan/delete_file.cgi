#!/usr/local/bin/perl
# delete_file.cgi
# Delete a downloaded package that is no longer needed

require './cpan-lib.pl';
&ReadParse();
$tmp_base = $gconfig{'tempdir'} || "/tmp/.webmin";
foreach $f (split(/\0/, $in{'file'})) {
	$f =~ /^\Q$tmp_base\E\// || &error($text{'delete_efile'});
	unlink($f);
	}
&redirect("");

