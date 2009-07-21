#!/usr/local/bin/perl
# Move an access control rule up (earlier)

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

&lock_slapd_files();

if (&get_config_type() == 1) {
	# Move up in old-style config
	$conf = &get_config();
	@access = &find("access", $conf);
	($access[$in{'idx'}-1], $access[$in{'idx'}]) =
		($access[$in{'idx'}], $access[$in{'idx'}-1]);
	&save_directive($conf, "access", @access);
	&flush_file_lines($config{'config_file'});
	}
else {
	# Move up in LDIF config
	$defdb = &get_default_db();
	$conf = &get_ldif_config();
	@access = &find_ldif("olcAccess", $conf, $defdb);
	($access[$in{'idx'}-1], $access[$in{'idx'}]) =
		($access[$in{'idx'}], $access[$in{'idx'}-1]);
	if ($access[$in{'idx'}]->{'values'}->[0] =~ /^\{\d+\}to/ &&
	    $access[$in{'idx'}-1]->{'values'}->[0] =~ /^\{\d+\}to/) {
		# Swap indexes too
		($access[$in{'idx'}]->{'values'}->[0],
		 $access[$in{'idx'}-1]->{'values'}->[0]) = 
			($access[$in{'idx'}-1]->{'values'}->[0],
			 $access[$in{'idx'}]->{'values'}->[0]);
		}
	&save_ldif_directive($conf, "olcAccess", $defdb, @access);
	&flush_file_lines();
	}

&unlock_slapd_files();

&webmin_log("up", "access", $p->{'what'});
&redirect("edit_acl.cgi");

