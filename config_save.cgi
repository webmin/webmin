#!/usr/local/bin/perl
# config_save.cgi
# Save inputs from config.cgi

BEGIN { push(@INC, "."); };
use WebminCore;
require './config-lib.pl';
&init_config();
&ReadParse();
$m = $in{'module'};
&error_setup($text{'config_err'});
%module_info = &get_module_info($m);
%module_info || &error($text{'config_emodule'});
&foreign_available($m) || $module_info{'noacl'} ||
	&error($text{'config_eaccess'});
%access = &get_module_acl(undef, $m);
$access{'noconfig'} && &error($text{'config_ecannot'});

mkdir("$config_directory/$m", 0700);
&lock_file("$config_directory/$m/config");
&read_file("$config_directory/$m/config", \%newconfig);
%oldconfig = %newconfig;

$mdir = &module_root_directory($m);
if (-r "$mdir/config_info.pl") {
	# Module has a custom config editor
	&foreign_require($m, "config_info.pl");
	local $fn = "${m}::config_form";
	if (defined(&$fn)) {
		$func++;
		&foreign_call($m, "config_save", \%newconfig);
		}
	}
if (!$func) {
	# Use config.info to parse config inputs
	my $cdir;
	foreach my $d (map { $_."/".$m } @theme_root_directories) {
		$cdir = $d if (-r $d."/config.info");
		}
	$cdir ||= $mdir;
	&parse_config(\%newconfig, "$cdir/config.info", $m);
	}
&write_file("$config_directory/$m/config", \%newconfig);
&unlock_file("$config_directory/$m/config");
&save_module_preferences($m, \%newconfig);

# Call any post-config save function
local $pfn = "${m}::config_post_save";
if (defined(&$pfn)) {
	&foreign_call($m, "config_post_save", \%newconfig, \%oldconfig);
	}

# Refresh installed modules
if (&foreign_check("webmin")) {
	&foreign_require("webmin", "webmin-lib.pl");
	&webmin::build_installed_modules(0, $m);
	}

&webmin_log("_config_", undef, undef, \%in, $m);
&redirect(&link_config_cparams($m, \%in));

