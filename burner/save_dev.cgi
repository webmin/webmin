#!/usr/local/bin/perl
# save_dev.cgi
# Save global device options

require './burner-lib.pl';
$access{'global'} || &error($text{'dev_ecannot'});
&ReadParse();
&error_setup($text{'dev_err'});

$config{'dev'} = $in{'dev'};
if ($in{'speed'}) {
	$config{'speed'} = $in{'speed'};
	}
else {
	$in{'other'} =~ /^\d+$/ || &error($text{'dev_eother'});
	$config{'speed'} = $in{'other'};
	}
$config{'extra'} = $in{'extra'};
&write_file("$module_config_directory/config", \%config);
&redirect("");

