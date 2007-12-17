#!/usr/local/bin/perl
# Move an access control rule down (later)

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Find it
&lock_file($config{'config_file'});
$conf = &get_config();
@access = &find("access", $conf);
$p = &parse_ldap_access($access[$in{'idx'}]);

# Move up
($access[$in{'idx'}+1], $access[$in{'idx'}]) =
	($access[$in{'idx'}], $access[$in{'idx'}+1]);
&save_directive($conf, "access", @access);
&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});

&webmin_log("down", "access", $p->{'what'});
&redirect("edit_acl.cgi");

