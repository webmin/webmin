#!/usr/local/bin/perl
# Just output a schema file

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'schema'} || &error($text{'schema_ecannot'});
&ReadParse();
&is_under_directory($config{'schema_dir'}, $in{'file'}) ||
	&error($text{'schema_edir'});
print "Content-type: text/plain\n\n";
print &read_file_contents($in{'file'});

