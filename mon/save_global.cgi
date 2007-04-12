#!/usr/local/bin/perl
# save_global.cgi
# Save global MON options

require './mon-lib.pl';
$conf = &get_mon_config();
&ReadParse();
&error_setup($text{'global_err'});

# Validate inputs
$in{'maxprocs'} =~ /^\d+$/ || &error($text{'global_emaxprocs'});
$in{'histlength'} =~ /^\d+$/ || &error($text{'global_ehistlength'});
-d $in{'alertdir'} ||  &error($text{'global_ealertdir'});
-d $in{'mondir'} ||  &error($text{'global_emondir'});
$in{'userfile_def'} || $in{'userfile'} =~ /^\S+$/ ||
	&error($text{'global_euserfile'});

# Update config file
$maxprocs = &find("maxprocs", $conf);
&save_directive($conf, $maxprocs, { 'name' => 'maxprocs',
				    'global' => 1,
				    'values' => [ $in{'maxprocs'} ] } );
$histlength = &find("histlength", $conf);
&save_directive($conf, $histlength, { 'name' => 'histlength',
				      'global' => 1,
				      'values' => [ $in{'histlength'} ] } );
$alertdir = &find("alertdir", $conf);
&save_directive($conf, $alertdir, { 'name' => 'alertdir',
				    'global' => 1,
				    'values' => [ $in{'alertdir'} ] } );
$mondir = &find("mondir", $conf);
&save_directive($conf, $mondir, { 'name' => 'mondir',
				  'global' => 1,
				  'values' => [ $in{'mondir'} ] } );
$authtype = &find("authtype", $conf);
if ($in{'authtype'}) {
	&save_directive($conf, $authtype, { 'name' => 'authtype',
					    'global' => 1,
					    'values' => [ $in{'authtype'} ] } );
	}
else {
	&save_directive($conf, $authtype) if ($authtype);
	}
$userfile = &find("userfile", $conf);
if ($in{'userfile_def'}) {
	&save_directive($conf, $userfile) if ($userfile);
	}
else {
	&save_directive($conf, $userfile, { 'name' => 'userfile',
					    'global' => 1,
					    'values' => [ $in{'userfile'} ] } );
	}

&flush_file_lines();
&redirect("");

