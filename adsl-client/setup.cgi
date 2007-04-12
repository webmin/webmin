#!/usr/local/bin/perl
# setup.sh
# Copy the default config file into place

require './adsl-client-lib.pl';
&lock_file($config{'pppoe_conf'});
&system_logged("cp $module_root_directory/ifcfg-ppp $config{'pppoe_conf'}");
if ($config{'pppoe_conf'} =~ /ifcfg-(ppp\d+)$/) {
	$conf = &get_config();
	&save_directive($conf, "DEVICE", "$1");
	&flush_file_lines();
	}
&unlock_file($config{'pppoe_conf'});
&webmin_log("setup");
&redirect("");

