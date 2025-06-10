#!/usr/local/bin/perl
# Save file locking settings

require './webmin-lib.pl';
&ReadParse();

# Validate inputs
&error_setup($text{'lock_err'});
if ($in{'lockmode'} >= 2) {
	@dirs = split(/\n+/, $in{'lockdirs'});
	foreach $d (@dirs) {
		$d =~ /^\// || &error(&text('lock_edir', $d));
		}
	@dirs || &error($text{'lock_edirs'});
	}

# Write out config
&lock_file($config_file);
$gconfig{'lockmode'} = $in{'lockmode'};
$gconfig{'lockdirs'} = join("\t", @dirs);
&save_module_config(\%gconfig, "");
&unlock_file($config_file);
&webmin_log("lock");

&redirect("");

