#!/usr/local/bin/perl
# Delete a bunch of access control rules

require './ldap-server-lib.pl';
&error_setup($text{'dacl_err'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Filter out un-wanted rules
&lock_slapd_files();

if (&get_config_type() == 1) {
	$conf = &get_config();
	@access = &find("access", $conf);
	}
else {
	$defdb = &get_default_db();
	$conf = &get_ldif_config();
	@access = &find_ldif("olcAccess", $conf, $defdb);
	}

%d = map { $_, 1 } split(/\0/, $in{'d'});
keys(%d) || &error($text{'dacl_enone'});
for($i=0; $i<@access; $i++) {
	push(@newaccess, $access[$i]) if (!$d{$i});
	}

# Save them
if (&get_config_type() == 1) {
	&save_directive($conf, "access", @newaccess);
	}
else {
	&save_ldif_directive($conf, "olcAccess", $defdb, @newaccess);
	}
&flush_file_lines();
&unlock_slapd_files();

&webmin_log("delete", "accesses", scalar(keys(%d)));
&redirect("edit_acl.cgi");

