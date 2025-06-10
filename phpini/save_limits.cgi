#!/usr/local/bin/perl
# Update options related to memory limits

require './phpini-lib.pl';
&error_setup($text{'limits_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

# Save memory limit
$in{"memory_limit_def"} || $in{"memory_limit"} =~ /^(\d+)(k|M|G|b|)$/ ||
	&error($text{'limits_emem'});
&save_directive($conf, "memory_limit",
		$in{"memory_limit_def"} ? undef : $in{"memory_limit"});

# Save POST limit
$in{"post_max_size_def"} || $in{"post_max_size"} =~ /^(\d+)(k|M|G|b|)$/ ||
	&error($text{'limits_epost'});
&save_directive($conf, "post_max_size",
		$in{"post_max_size_def"} ? undef : $in{"post_max_size"});

# Save upload limit
$in{"upload_max_filesize_def"} ||
    $in{"upload_max_filesize"} =~ /^(\d+)(k|M|G|b|)$/ ||
	&error($text{'limits_eupload'});
&save_directive($conf, "upload_max_filesize",
		$in{"upload_max_filesize_def"} ? undef
					       : $in{"upload_max_filesize"});

# Save max run time
$in{"max_execution_time_def"} || $in{"max_execution_time"} =~ /^\-?\d+$/ ||
	&error($text{'limits_emem'});
&save_directive($conf, "max_execution_time",
	$in{"max_execution_time_def"} ? undef : $in{"max_execution_time"});

# Save max parsing time
$in{"max_input_time_def"} || $in{"max_input_time"} =~ /^\-?\d+$/ ||
	&error($text{'limits_einput'});
&save_directive($conf, "max_input_time",
	$in{"max_input_time_def"} ? undef : $in{"max_input_time"});

# Save max input vars limit
$in{"max_input_vars_def"} || $in{"max_input_vars"} =~ /^\d+$/ ||
	&error($text{'limits_evars'});
&save_directive($conf, "max_input_vars",
	$in{"max_input_vars_def"} ? undef : $in{"max_input_vars"});

&flush_file_lines_as_user($in{'file'}, undef, 1);
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("limits", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

