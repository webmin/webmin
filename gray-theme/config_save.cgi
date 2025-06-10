#!/usr/local/bin/perl
# config_save.cgi
# Save inputs from config.cgi

require "gray-theme/gray-theme-lib.pl";
require './config-lib.pl';
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
%oldconfig  = %newconfig;

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
	&parse_config(\%newconfig, "$mdir/config.info", $m, undef, $in{'section'});
	}
&write_file("$config_directory/$m/config", \%newconfig);
&unlock_file("$config_directory/$m/config");
&save_module_preferences($m, \%newconfig);

# Call any post-config save function
if (&foreign_require($m) &&
    &foreign_defined($m, 'config_post_save')) {
	&foreign_call($m, "config_post_save", \%newconfig, \%oldconfig)
	}

&webmin_log("_config_", undef, undef, \%in, $m);
if ($in{'save_next'}) {
	$redir = &link_config_cparams($m, \%in, 1);
	$params = $redir =~ /\?(.*)$/ ? "&".$1 : "";
	&redirect("config.cgi?module=$in{'module'}&section=$in{'section_next'}".
		  $params);
	}
elsif ($m eq "virtual-server") {
	&redirect("/right.cgi");
	}
else {
	$redir = &link_config_cparams($m, \%in);
	&redirect($redir);
	}

