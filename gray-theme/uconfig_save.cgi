#!/usr/local/bin/perl
# config_save.cgi
# Save inputs from config.cgi

require "gray-theme/gray-theme-lib.pl";
require './config-lib.pl';
&ReadParse();
$m = $in{'module'};
&error_setup($text{'config_err'});

# Reject paths before resolving or loading module files
defined($m) && $m =~ /\A[A-Za-z0-9_-]+\z/ || &error($text{'config_emodule'});
&foreign_available($m) || &error($text{'config_eaccess'});
&switch_to_remote_user();
&create_user_config_dirs();

# Personal preferences exist only where per-user config directories do
$user_config_directory || &error($text{'config_ecannot'});

mkdir("$user_config_directory/$m", 0700);
&lock_file("$user_config_directory/$m/config");
&read_file("$user_config_directory/$m/config", \%newconfig);
&read_file("$config_directory/$m/canconfig", \%canconfig);

$mdir = &module_root_directory($m);
if (-r "$mdir/uconfig_info.pl") {
	# Module has a custom config editor
	&foreign_require($m, "uconfig_info.pl");
	local $fn = "${m}::config_form";
	if (defined(&$fn)) {
		$func++;
		&foreign_call($m, "config_save", \%newconfig, \%canconfig);
		}
	}
if (!$func) {
	# Use config.info to parse config inputs
	&parse_config(\%newconfig, "$mdir/uconfig.info", $m,
		      %canconfig ? \%canconfig : undef, $in{'section'});
	}
&write_file("$user_config_directory/$m/config", \%newconfig);
&unlock_file("$user_config_directory/$m/config");

# Call any post-config save function
local $pfn = "${m}::config_post_save";
if (defined(&$pfn)) {
	&foreign_call($m, "config_post_save", \%newconfig, \%oldconfig,
					      \%canconfig);
	}

if ($in{'save_next'}) {
	&redirect("uconfig.cgi?module=".&urlize($m).
		  "&section=".&urlize($in{'section_next'}));
	}
else {
	&redirect("/$m/");
	}

