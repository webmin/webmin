#!/usr/local/bin/perl
# Write out a schema file

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ReadParseMime();

# Validate
&error_setup($text{'schema_eerr'});
&is_under_directory($config{'schema_dir'}, $in{'file'}) ||
	&error($text{'schema_edir'});
$in{'data'} =~ s/\r//g;
$in{'data'} =~ /\S/ || &error($text{'schema_edata'});

# Save
&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);

&webmin_log("sfile", undef, $in{'file'});
&redirect("edit_schema.cgi");

