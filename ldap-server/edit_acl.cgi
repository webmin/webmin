#!/usr/local/bin/perl
# Show access control settings from config

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'acl_title'}, "", "acl");


