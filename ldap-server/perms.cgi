#!/usr/local/bin/perl
# Fix file ownership, and then restart if running

require './ldap-server-lib.pl';
&ReadParse();
&error_setup($text{'perms_err'});
# The permission that applies depends on the server config type
$access{&get_config_type() == 2 ? 'ldif' : 'slapd'} ||
	&error($text{'slapd_ecannot'});

&system_logged("chown -R $config{'ldap_user'} ".quotemeta($config{'data_dir'}));
if (&is_ldap_server_running()) {
	&stop_ldap_server();
	$err = &start_ldap_server();
	&error($err) if ($err);
	}
&webmin_log("perms");
&redirect("");

