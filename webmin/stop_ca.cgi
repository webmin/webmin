#!/usr/local/bin/perl
# stop_ca.cgi
# Remove all the CA files

require './webmin-lib.pl';
&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
delete($miniserv{'ca'});
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

$acl = "$config_directory/acl";
&lock_file("$acl/ca.pem");
unlink("$acl/ca.pem");
&unlock_file("$acl/ca.pem");

&lock_file("$acl/index.txt");
unlink("$acl/index.txt");
&unlock_file("$acl/index.txt");

&lock_file("$acl/index.txt.old");
unlink("$acl/index.txt.old");
&unlock_file("$acl/index.txt.old");

&lock_file("$acl/openssl.cnf");
unlink("$acl/openssl.cnf");
&unlock_file("$acl/openssl.cnf");

&lock_file("$acl/serial");
unlink("$acl/serial");
&lock_file("$acl/serial");

&lock_file("$acl/serial.old");
unlink("$acl/serial.old");
&unlock_file("$acl/serial.old");
&system_logged("rm -rf $acl/newcerts");

&ui_print_header(undef, $text{'ca_title'}, "");
print "<p>$text{'ca_stopok'}<p>\n";
&ui_print_footer("", $text{'index_return'});
&restart_miniserv(1);
&webmin_log("stopca", undef, undef);

