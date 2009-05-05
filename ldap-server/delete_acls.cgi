#!/usr/local/bin/perl
# Delete a bunch of access control rules

require './ldap-server-lib.pl';
&error_setup($text{'dacl_err'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Filter out un-wanted rules
&lock_slapd_files();
$conf = &get_config();
@access = &find("access", $conf);
%d = map { $_, 1 } split(/\0/, $in{'d'});
keys(%d) || &error($text{'dacl_enone'});
for($i=0; $i<@access; $i++) {
	push(@newaccess, $access[$i]) if (!$d{$i});
	}

# Save them
&save_directive($conf, "access", @newaccess);
&flush_file_lines($config{'config_file'});
&unlock_slapd_files();

&webmin_log("delete", "accesses", scalar(keys(%d)));
&redirect("edit_acl.cgi");

