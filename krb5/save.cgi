#!/usr/local/bin/perl
# start.cgi
# Save config

require './krb5-lib.pl';

&ReadParse();
&error_setup($text{'save_err', $config{'krb5_conf'}});

# Write the config file
&lock_file($config{'krb5_conf'});
open(FILE, "> $config{'krb5_conf'}");
print FILE "[logging]\n";
print FILE "default = FILE:$in{'default_log'}\n";
print FILE "kdc = FILE:$in{'kdc_log'}\n";
print FILE "admin_server = FILE:$in{'admin_log'}\n";
print FILE "\n";
print FILE "[libdefaults]\n";
print FILE "default_realm = $in{'default_realm'}\n";
if (!$in{'dns_kdc'}) {
    print FILE "dns_lookup_kdc = false\n";
}
print FILE "\n";
print FILE "[realms]\n";
print FILE "$in{'default_realm'} = {\n";
print FILE "   default_domain = $in{'default_domain'}\n";
print FILE "   kdc = $in{'default_kdc'}:$in{'default_kdc_port'}\n";
print FILE "   admin_server = $in{'default_admin'}:$in{'default_admin_port'}\n";
print FILE "}\n";
print FILE "\n";
print FILE "[domain_realm]\n";
print FILE "$in{'domain'} = $in{'default_realm'}\n";
print FILE "\n";
close(FILE);
&unlock_file($config{'krb5_conf'});

&redirect("");
