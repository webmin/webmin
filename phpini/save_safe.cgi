#!/usr/local/bin/perl
# Update options related to safe mode

require './phpini-lib.pl';
&error_setup($text{'safe_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

# Validate and store inputs
&save_directive($conf, "safe_mode", $in{"safe_mode"} || undef);
&save_directive($conf, "safe_mode_gid", $in{"safe_mode_gid"} || undef);

foreach $d ([ "safe_mode_include_dir", "safe_einclude" ],
	    [ "safe_mode_exec_dir", "safe_eexec" ],
	    [ "open_basedir", "safe_ebasedir" ]) {
	if ($in{$d->[0]."_def"}) {
		&save_directive($conf, $d->[0], undef);
		}
	else {
		foreach my $d (split(/:/, $in{$d->[0]})) {
			-d $d || &error($text{$d->[1]});
			}
		&save_directive($conf, $d->[0], $in{$d->[0]});
		}
	}

&flush_file_lines_as_user($in{'file'});
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("safe", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

