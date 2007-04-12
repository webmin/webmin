#!/usr/local/bin/perl
# save_global.cgi
# Save global options

require './lilo-lib.pl';
&ReadParse();
&lock_file($config{'lilo_conf'});
$conf = &get_lilo_conf();
&error_setup($text{'global_err'});

&save_directive($conf, "boot",
		$in{'bootmode'} ? { 'name' => 'boot', 'value' => $in{'boot'} }
				: undef);
&save_directive($conf, "default",
		$in{'defaultmode'} ? { 'name' => 'default',
				       'value' => $in{'default'} } : undef);
&save_directive($conf, "prompt",
		$in{'prompt'} ? { 'name' => 'prompt' } : undef);
&save_directive($conf, "timeout",
		$in{'timeout_def'} ? undef :
		{ 'name' => 'timeout', 'value' => $in{'timeout'}*10 });
&save_directive($conf, "lock",
		$in{'lock'} ? { 'name' => 'lock' } : undef);
&save_directive($conf, "delay",
		$in{'delay_def'} ? undef :
		{ 'name' => 'delay', 'value' => $in{'delay'}*10 });
&save_directive($conf, "compact",
		$in{'compact'} ? { 'name' => 'compact' } : undef);
&save_directive($conf, "optional",
		$in{'optional'} ? { 'name' => 'optional' } : undef);
&save_directive($conf, "password",
		$in{'passmode'} ? { 'name' => 'password',
				    'value' => $in{'password'} } : undef);
&save_directive($conf, "restricted",
		$in{'restricted'} ? { 'name' => 'restricted' } : undef);
if ($lilo_version >= 21.3) {
	&save_directive($conf, "lba32",
			$in{'lba'} ? { 'name' => 'lba32' } : undef);
	}
&flush_file_lines();
&unlock_file($config{'lilo_conf'});
&webmin_log("global", undef, undef, \%in);
&redirect("");

