#!/usr/bin/perl
# Save the contents of a table file

require './shorewall6-lib.pl';
&ReadParseMime();
&can_access($in{'table'}) || &error($text{'list_ecannot'});
&error_setup($text{'manual_err'});
$file = "$config{'config_dir'}/$in{'table'}";
$in{'table'} =~ /\.\./ && &error($text{'manual_efile'});
$in{'data'} =~ s/\r//g;
$in{'data'} || &error($text{'manual_edata'});

&open_lock_tempfile(FILE, ">$file");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);
&webmin_log('manual', 'table', $in{'table'});
&redirect("list.cgi?table=$in{'table'}");

