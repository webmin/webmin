#!/usr/local/bin/perl
# edit_ca.cgi
# Display the current CA or a form for creating one

require './webmin-lib.pl';
ui_print_header(undef, $text{'ca_title'}, "");
get_miniserv_config(\%miniserv);

%aclconfig = foreign_config("acl");
foreign_require("acl", "acl-lib.pl");
if (!$ENV{"MINISERV_CONFIG"}) {
	print "<p>$text{'ca_eminiserv'}<p>\n";
	ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif (uc($ENV{'HTTPS'}) ne 'ON') {
	print "<p>$text{'ca_essl'}<p>\n";
	ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif (!defined(&Net::SSLeay::X509_STORE_CTX_get_current_cert) ||
       !defined(&Net::SSLeay::CTX_load_verify_locations) ||
       !defined(&Net::SSLeay::CTX_set_verify)) {
	print "<p>$text{'ca_eversion'}<p>\n";
	ui_print_footer("", $text{'index_return'});
	exit;
	}
elsif (!acl::get_ssleay()) {
	print "<p>",text('ca_essleay',
			  "<tt>$aclconfig{'ssleay'}</tt>"),"<p>\n";
	ui_print_footer("", $text{'index_return'});
	exit;
	}

print -r $miniserv{'ca'} ? $text{'ca_newmsg1'} : $text{'ca_newmsg1'},"<p>\n";

print ui_form_start("setup_ca.cgi", "post");
print ui_table_start($text{'ca_header1'}, undef, 2);

print &ui_table_row($text{'ca_cn'},
		    &ui_textbox("commonName", undef, 30), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ca_email'},
		    &ui_textbox("emailAddress", undef, 30), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ca_ou'},
		    &ui_textbox("organizationalUnitName", undef, 30), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ca_o'},
		    &ui_textbox("organizationName", undef, 30), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ca_sp'},
		    &ui_textbox("stateOrProvinceName", undef, 15), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ca_c'},
		    &ui_textbox("countryName", undef, 2), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ssl_size'},
                    &ui_opt_textbox("size", undef, 6,
                                    "$text{'default'} ($default_key_size)").
                    " ".$text{'ssl_bits'}, undef, [ "valign=middle","valign=middle" ]);

print ui_table_end();
print ui_form_end([ [ "create", $text{'ca_create'} ] ]);

print ui_hr();

print -r $miniserv{'ca'} ? $text{'ca_oldmsg1'} : $text{'ca_oldmsg2'},"<p>\n";

print ui_form_start("change_ca.cgi", "form-data");
print ui_table_start($text{'ca_header2'}, undef, 2);
print ui_table_row(undef,
	&ui_textarea("rows",
		$miniserv{'ca'} ? &read_file_contents($miniserv{'ca'}) : undef,
		20, 70));
print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);

if (-r $miniserv{'ca'}) {
	print ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("stop_ca.cgi", $text{'ca_stop'},
			      $text{'ca_stopmsg'});
	print &ui_buttons_end();
	}

ui_print_footer("", $text{'index_return'});

