#!/usr/local/bin/perl
# save_global.cgi
# Save global GRUB options

require './grub-lib.pl';
&ReadParse();
&error_setup($text{'global_err'});
&lock_file($config{'menu_file'});
$conf = &get_menu_config();
&error_setup($text{'global_err'});

# validate and save inputs
if ($in{'default'} eq '') {
	&save_directive($conf, 'default', undef);
	}
else {
	&save_directive($conf, 'default', { 'name' => 'default',
					    'value' => $in{'default'} });
	}
if ($in{'fallback'} eq '') {
	&save_directive($conf, 'fallback', undef);
	}
else {
	&save_directive($conf, 'fallback', { 'name' => 'fallback',
					     'value' => $in{'fallback'} });
	}
if ($in{'timeout_def'}) {
	&save_directive($conf, 'timeout', undef);
	}
else {
	$in{'timeout'} =~ /^\d+$/ || &error($text{'global_etimeout'});
	&save_directive($conf, 'timeout', { 'name' => 'timeout',
					    'value' => $in{'timeout'} });
	}
if ($in{'password_def'}) {
	&save_directive($conf, 'password', undef);
	}
else {
	$in{'password'} =~ /^\S+$/ || &error($text{'global_epassword'});
	if (!$in{'password_file'}) {
		&save_directive($conf, 'password', { 'name' => 'password',
		    'value' => $in{'password'} } );
		}
	else {
		$in{'password_filename'} =~ /^\S+$/ ||
			&error($text{'global_epasswordfile'});
		&save_directive($conf, 'password', { 'name' => 'password',
		    'value' => $in{'password'}.' '.$in{'password_filename'} } );
		}
	}
if ($in{'install_mode'} == 1) {
	$install = &linux_to_bios($in{'install'});
	$install || &error(&text('global_edev', $in{'root'}));
	$config{'install'} = $install;
	}
else {
	$in{'other'} =~ /^\S+$/ || &error($text{'global_eother'});
	$config{'install'} = $in{'other'};
	}
&write_file("$module_config_directory/config", \%config);
&flush_file_lines($config{'menu_file'});
&unlock_file($config{'menu_file'});
&webmin_log("global");
&redirect("");

