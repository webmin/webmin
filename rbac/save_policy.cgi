#!/usr/local/bin/perl
# Save global policy settings

require './rbac-lib.pl';
$access{'policy'} || &error($text{'policy_ecannot'});
&error_setup($text{'policy_err'});
&lock_rbac_files();
$conf = &get_policy_config();
&ReadParse();

# Validate and save inputs
$auths = &auths_parse("auths");
&save_policy($conf, "AUTHS_GRANTED", $auths);
$profs = &profiles_parse("profs");
&save_policy($conf, "PROFS_GRANTED", $profs);

if ($in{'allow_def'}) {
	&save_policy($conf, "CRYPT_ALGORITHMS_ALLOW", undef);
	}
else {
	$allow = join(",", split(/\0/, $in{'allow'}));
	$allow || &error($text{'policy_eallow'});
	$in{'deprecate_def'} || &error($text{'policy_eclash'});
	&save_policy($conf, "CRYPT_ALGORITHMS_ALLOW", $allow);
	}

if ($in{'default_def'}) {
	&save_policy($conf, "CRYPT_DEFAULT", undef);
	}
else {
	&save_policy($conf, "CRYPT_DEFAULT", $in{'default'});
	}

if ($in{'deprecate_def'}) {
	&save_policy($conf, "CRYPT_ALGORITHMS_DEPRECATE", undef);
	}
else {
	&save_policy($conf, "CRYPT_ALGORITHMS_DEPRECATE", $in{'deprecate'});
	}

&flush_file_lines();
&unlock_rbac_files();
&webmin_log("policy");
&redirect("");

