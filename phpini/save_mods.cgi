#!/usr/local/bin/perl
# Enable or disable PHP modules

require './phpini-lib.pl';
&error_setup($text{'mods_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$inidir = &get_php_ini_dir($in{'file'});
$inidir || &error($text{'mods_edir'});
$access{'global'} || &error($text{'mods_ecannot'});

@mods = &list_php_ini_modules($inidir);
%enable = map { $_, 1 } split(/\0/, $in{'mod'});
foreach my $m (@mods) {
	&enable_php_ini_module($m, $enable{$m->{'mod'}});
	}

&graceful_apache_restart($in{'file'});
&webmin_log("mods", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));


