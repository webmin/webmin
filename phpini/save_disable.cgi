#!/usr/local/bin/perl
# Update disabled functions and classes

require './phpini-lib.pl';
&error_setup($text{'disable_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

# Save disabled functions
@disfunc = split(/\0/, $in{'disable_functions'});
push(@disfunc, split(/[ \t,]+/, $in{'leftover'})) if ($in{'disable_leftover'});
&save_directive($conf, "disable_functions",
		@disfunc ? join(",", @disfunc) : undef);

# Save disabled classes
&save_directive($conf, "disable_classes", $in{'disable_classes'} || undef);

&flush_file_lines_as_user($in{'file'}, undef, 1);
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("disable", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

