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
&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);

&graceful_apache_restart();
&webmin_log("manual", $in{'file'});
if ($in{'oneini'}) {
	&redirect("list_ini.cgi?file=".&urlize($in{'file'}));
	}
else {
	&redirect("");
	}
