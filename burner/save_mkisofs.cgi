#!/usr/local/bin/perl
# save_mkisofs.cgi
# Save global ISO filesystem options

require './burner-lib.pl';
$access{'global'} || &error($text{'mkisofs_ecannot'});
&ReadParse();

$config{'novers'} = $in{'novers'};
$config{'notrans'} = $in{'notrans'};
$config{'nobak'} = $in{'nobak'};
$config{'fsyms'} = $in{'fsyms'};
&write_file("$module_config_directory/config", \%config);
&redirect("");

