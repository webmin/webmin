#!/usr/local/bin/perl
# Link PAM LDAP file to NSS file

require './ldap-client-lib.pl';
&ReadParse();

if ($in{'ignore'}) {
	# Don't show message anymore
	$config{'nofixpam'} = 1;
	&save_module_config();
	}
else {
	# Fix up
	&unlink_logged($config{'pam_ldap'});
	&symlink_logged(&get_ldap_config_file(), $config{'pam_ldap'});
	&webmin_log("fixpam");
	}
&redirect("");


