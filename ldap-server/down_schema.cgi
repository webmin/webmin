#!/usr/local/bin/perl
# Move a schema include down (later)

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'schema'} || &error($text{'schema_ecannot'});
&ReadParse();

# Find it includes
&lock_slapd_files();
$conf = &get_config();
@incs = &find_value("include", $conf);
$idx = &indexof($in{'file'}, @incs);
$idx > 0 || &error($text{'schema_emove'});

# Move up
($incs[$idx+1], $incs[$idx]) = ($incs[$idx], $incs[$idx+1]);
&save_directive($conf, "include", @incs);
&flush_file_lines($config{'config_file'});
&unlock_slapd_files();

&webmin_log("sup", undef, $in{'file'});
&redirect("edit_schema.cgi");

