#!/usr/local/bin/perl
# Save included schema files

require './ldap-server-lib.pl';
&error_setup($text{'schema_err'});
$access{'schema'} || &error($text{'schema_ecannot'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ReadParse();

# Get non-schema includes
$conf = &get_config();
foreach $i (&find_value("include", $conf)) {
	if ($i !~ /^(.*)\/(\S+)$/ || $1 ne $config{'schema_dir'} ||
				     $2 eq 'core.schema') {
		push(@incs, $i);
		}
	}

# Build new list of includes, which must be files in the schema directory
foreach $d (split(/\0/, $in{'d'})) {
	$d =~ /^(.*)\/([^\/\r\n]+)\z/ && $1 eq $config{'schema_dir'} ||
		&error($text{'schema_edir'});
	push(@incs, $d);
	}
@incs = &unique(@incs);

# Write out
&lock_slapd_files();
&save_directive($conf, "include", @incs);
&flush_file_lines($config{'config_file'});
&unlock_slapd_files();

&webmin_log("schema");
&redirect("");

