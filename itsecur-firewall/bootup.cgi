#!/usr/bin/perl
# bootup.cgi
# Enable or disable iptables at boot time

require './itsecur-lib.pl';
&can_edit_error("bootup");
&ReadParse();
&foreign_require("init", "init-lib.pl");
&foreign_require("cron", "cron-lib.pl");

# Create the wrapper script
$start_wrapper_script = "$module_config_directory/apply.pl";
$stop_wrapper_script = "$module_config_directory/stop.pl";
&cron::create_wrapper($start_wrapper_script, $module_name, "apply.pl");
&cron::create_wrapper($stop_wrapper_script, $module_name, "stop.pl");

if ($in{'boot'}) {
	&init::enable_at_boot("itsecur-firewall",
			      "Start or stop the ITsecur firewall",
			      $start_wrapper_script,
			      $stop_wrapper_script);
	&remote_webmin_log("bootup");
	}
else {
	&init::disable_at_boot("itsecur-firewall");
	&remote_webmin_log("bootdown");
	}

&redirect("");

