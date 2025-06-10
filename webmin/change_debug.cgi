#!/usr/local/bin/perl
# Save debug mode options

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'debug_err'});

# Validate and store inputs
&lock_file("$config_directory/config");
$gconfig{'debug_enabled'} = $in{'debug_enabled'};

# What to log
$count = 0;
foreach $w (@debug_what_events) {
	$gconfig{'debug_what_'.$w} = $in{'debug_what_'.$w};
	$count++ if ($in{'debug_what_'.$w});
	}
$count || &error($text{'debug_ewhat'});

# Log file
if ($in{'debug_file_def'}) {
	delete($gconfig{'debug_file'});
	}
else {
	$in{'debug_file'} =~ /^(.*\/)([^\/]+)$/ ||
		&error($text{'debug_efile'});
	-d $1 || &error(&text('debug_edir', "$1"));
	$gconfig{'debug_file'} = $in{'debug_file'};
	}

# Size before clearing
if ($in{'debug_size_def'}) {
	delete($gconfig{'debug_size'});
	}
else {
	$in{'debug_size'} =~ /^\d+$/ || &error($text{'debug_esize'});
	$gconfig{'debug_size'} = $in{'debug_size'}*$in{'debug_size_units'};
	}

# What to debug
$gconfig{'debug_noweb'} = !$in{'debug_web'};
$gconfig{'debug_nocmd'} = !$in{'debug_cmd'};
$gconfig{'debug_nocron'} = !$in{'debug_cron'};

# Modules
if ($in{'mall'}) {
	delete($gconfig{'debug_modules'});
	}
else {
	$in{'modules'} || &error($text{'debug_emodules'});
	$gconfig{'debug_modules'} = join(' ', split(/\0/, $in{'modules'}));
	}

# Write out
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&webmin_log("debug");
&redirect("");

