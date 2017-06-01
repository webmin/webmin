#!/usr/local/bin/perl
# Update options related to PHP directories

require './phpini-lib.pl';
&error_setup($text{'dirs_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

# Validate and save inputs
if ($in{'include_def'}) {
	&save_directive($conf, "include_path", undef);
	}
else {
	@incs = split(/\r?\n/, $in{'include'});
	@incs || &error($text{'dirs_eincs'});
	&save_directive($conf, "include_path", join(":", @incs));
	}

$in{'ext_def'} || $in{'ext'} =~ /\S/ || &error($text{'dirs_eext'});
&save_directive($conf, "extension_dir", $in{'ext_def'} ? undef : $in{'ext'});

&save_directive($conf, "file_uploads", $in{'file_uploads'} || undef);

$in{'utmp_def'} || -d $in{'utmp'} || &error($text{'dirs_eutmp'});
&save_directive($conf, "upload_tmp_dir", $in{'utmp_def'} ? undef : $in{'utmp'});

&flush_file_lines_as_user($in{'file'});
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("dirs", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

