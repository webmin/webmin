#!/usr/local/bin/perl
# Update options related to PHP variables

require './phpini-lib.pl';
&error_setup($text{'vars_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

foreach $v ("magic_quotes_gpc", "magic_quotes_runtime",
	    "register_globals", "register_long_arrays",
	    "register_argc_argv") {
	&save_directive($conf, $v, $in{$v} || undef);
	}
&flush_file_lines_as_user($in{'file'});
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("vars", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

