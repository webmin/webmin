#!/usr/local/bin/perl
# Show a form for certificate generation

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});

&ui_print_header(undef, $text{'gencert_title'}, "");


&ui_print_footer("", $text{'index_return'});


