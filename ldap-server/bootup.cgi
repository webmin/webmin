#!/usr/local/bin/perl
# Enable or disable the LDAP server at boot

require './ldap-server-lib.pl';
&error_setup($text{'bootup_err'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'start'} || &error($text{'bootup_ecannot'});
&ReadParse();

&foreign_require("init", "init-lib.pl");
$iname = $config{'init_name'} || $module_name;
if ($in{'boot'}) {
	$pidfile = &get_ldap_server_pidfile();
	&init::enable_at_boot($iname, "Start OpenLDAP server",
			      "$config{'slapd'} 2>&1 </dev/null",
			      "kill `cat $pidfile`");
	}
else {
	&init::disable_at_boot($iname);
	}
&webmin_log("boot", undef, $in{'boot'});
&redirect("");

