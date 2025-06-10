#!/usr/local/bin/perl
# Update options related to error logging

require './phpini-lib.pl';
&error_setup($text{'errors_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

&save_directive($conf, "display_errors", $in{"display_errors"} || undef);
&save_directive($conf, "log_errors", $in{"log_errors"} || undef);
&save_directive($conf, "ignore_repeated_errors",
		$in{"ignore_repeated_errors"} || undef);
&save_directive($conf, "ignore_repeated_source",
		$in{"ignore_repeated_source"} || undef);
if (defined($in{"error_reporting"})) {
	# Custom expression
	if ($in{"error_reporting_def"}) {
		&save_directive($conf, "error_reporting", undef);
		}
	else {
		$in{"error_reporting"} =~ /\S/ ||
			&error($text{'errors_ereporting'});
		&save_directive($conf, "error_reporting",
				$in{"error_reporting"}, undef, 1);
		}
	}
else {
	# Bitwise
	&save_directive($conf, "error_reporting",
			join("|", split(/\0/, $in{"error_bits"})));
	}

# Save max error length
$in{"log_errors_max_len_def"} || $in{"log_errors_max_len"} =~ /^\d+$/ ||
	&error($text{'errors_emaxlen'});
&save_directive($conf, "log_errors_max_len", 
	$in{"log_errors_max_len_def"} ? undef : $in{"log_errors_max_len"});

# Save log file
if ($in{"error_log_def"} == 0) {
	&save_directive($conf, "error_log", undef);
	}
elsif ($in{"error_log_def"} == 1) {
	&save_directive($conf, "error_log", "syslog");
	}
elsif ($in{"error_log_def"} == 2) {
	$in{"error_log"} =~ /\S/ || &error($text{'errors_efile'});
	&save_directive($conf, "error_log", $in{"error_log"});
	}

&flush_file_lines_as_user($in{'file'}, undef, 1);
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("errors", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

