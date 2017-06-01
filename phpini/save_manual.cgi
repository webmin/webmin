#!/usr/local/bin/perl
# Write to a manually edited PHP config file

require './phpini-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});
&can_php_config($in{'file'}) || &error($text{'manual_ecannot'});
$access{'manual'} || &error($text{'manual_ecannot'});

# Validate input
$in{'data'} =~ s/\r//g;
$in{'data'} =~ /\S/ || &error($text{'manual_edata'});

# Save the file
&write_file_contents_as_user($in{'file'}, $in{'data'});

&graceful_apache_restart($in{'file'});
&webmin_log("manual", $in{'file'});
if ($in{'oneini'}) {
	&redirect("list_ini.cgi?file=".&urlize($in{'file'}));
	}
else {
	&redirect("");
	}
