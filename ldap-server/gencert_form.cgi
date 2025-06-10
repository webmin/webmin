#!/usr/local/bin/perl
# Show a form for certificate generation

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
&foreign_require("webmin", "webmin-lib.pl");

&ui_print_header(undef, $text{'gencert_title'}, "");

print $text{'gencert_desc'},"<p>\n";
print &ui_form_start(&get_config_type() == 1 ? "gencert.cgi"
					     : "gencert_ldif.cgi", "post");
print &ui_table_start($text{'gencert_header'}, undef, 2, [ "width=30%" ]);

# Generic key options
print &webmin::show_ssl_key_form(
	&get_display_hostname(), undef,
	"LDAP server on ".&get_display_hostname());

# Destination files
if (&get_config_type() == 1) {
	$conf = &get_config();
	$cert = &find_value("TLSCertificateFile", $conf);
	}
else {
	$conf = &get_ldif_config();
	$cert = &find_ldif_value(
		"olcTLSCertificateFile", $conf, &get_config_db());
	}
if ($cert) {
	print &ui_table_row($text{'gencert_dest'},
		&ui_opt_textbox("dest", undef, 40, $text{'gencert_same'},
				$text{'gencert_dir'}));
	}
else {
	print &ui_table_row($text{'gencert_dest2'},
		&ui_textbox("dest", &get_config_dir(), 40));
	}

print &ui_table_end();
print &ui_form_end([ [ "", $text{'gencert_create'} ] ]);

&ui_print_footer("", $text{'index_return'});


