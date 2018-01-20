#!/usr/local/bin/perl
# Save a manually edited config file

require './mysql-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});

# Validate the filename
$conf = &get_mysql_config();
@files = &unique(map { $_->{'file'} } @$conf);
$in{'manual'} ||= $files[0];
&indexof($in{'manual'}, @files) >= 0 ||
	&error($text{'manual_efile'});

# Write the file
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(MANUAL, ">$in{'manual'}");
&print_tempfile(MANUAL, $in{'data'});
&close_tempfile(MANUAL);

&webmin_log("manual");
&redirect("");
