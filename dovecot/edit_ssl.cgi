#!/usr/local/bin/perl
# Show SSL options

require './dovecot-lib.pl';
&ui_print_header(undef, $text{'ssl_title'}, "");
$conf = &get_config();

print &ui_form_start("save_ssl.cgi", "post");
print &ui_table_start($text{'ssl_header'}, "width=100%", 4);

# SSL cert and key files
if (&version_atleast("2.4")) {
	$cert = &find_value('ssl_server_cert_file', $conf, 0, "");
	$cert =~ s/^<//;
	}
elsif (&find_value("ssl_cert", $conf, 2) || &version_atleast("2.2")) {
	$cert = &find_value("ssl_cert", $conf, 0, "");
	$cert =~ s/^<//;
	}
else {
	$cert = &find_value("ssl_cert_file", $conf);
	}
print &ui_table_row($text{'ssl_cert'},
	    &ui_opt_textbox("cert", $cert, 40, &getdef("ssl_cert_file")), 3,
	    [ undef, "nowrap" ]);

if (&version_atleast("2.4")) {
	$key = &find_value('ssl_server_key_file', $conf, 0, "");
	$key =~ s/^<//;
	}
elsif (&find_value("ssl_key", $conf, 2) || &version_atleast("2.2")) {
	$key = &find_value("ssl_key", $conf, 0, "");
	$key =~ s/^<//;
	}
else {
	$key = &find_value("ssl_key_file", $conf);
	}
print &ui_table_row($text{'ssl_key'},
	    &ui_opt_textbox("key", $key, 40, &getdef("ssl_key_file")), 3,
	    [ undef, "nowrap" ]);

# SSL CA file
if (&version_atleast("2.4")) {
	$ca = &find_value('ssl_server_ca_file', $conf, 0, "");
	$ca =~ s/^<//;
	}
elsif (&find_value("ssl_ca", $conf, 2) || &version_atleast("2.2")) {
	$ca = &find_value("ssl_ca", $conf, 0, "");
	$ca =~ s/^<//;
	}
else {
	$ca = &find_value("ssl_ca_file", $conf);
	}
print &ui_table_row($text{'ssl_ca'},
	    &ui_opt_textbox("ca", $ca, 40,
		&getdef("ssl_ca_file", [ [ "", $text{'ssl_none'} ] ])), 3,
	    [ undef, "nowrap" ]);

# SSL key password
my $passdir = &version_atleast("2.4")
	? "ssl_server_key_password"
	: "ssl_key_password";
$pass = &find_value($passdir, $conf);
print &ui_table_row($text{'ssl_pass'},
	    &ui_opt_textbox("pass", $pass, 20, $text{'ssl_prompt'}), 3,
	    [ undef, "nowrap" ]);

# Parameter regen time
if (&version_below("2.4")) {
	$regen = &find_value("ssl_parameters_regenerate", $conf);
	print &ui_table_row($text{'ssl_regen'},
			&ui_opt_textbox("regen", $regen, 5,
					&getdef("ssl_parameters_regenerate")).
					" ".$text{'ssl_hours'}, 3);
	}

# Disable plaintext passwords when not SSL
if (&find_value("auth_allow_cleartext", $conf, 2)) {
	@opts = ( [ 'yes', $text{'yes'} ], [ 'no', $text{'no'} ] );
	$plain = &find_value("auth_allow_cleartext", $conf);
	print &ui_table_row($text{'ssl_plain2'},
	    &ui_radio("plain", $plain,
		      [ @opts,
			[ '', "$text{'default'} (No)" ] ]), 3);
	}
else {
	@opts = ( [ 'yes', $text{'yes'} ], [ 'no', $text{'no'} ] );
	$plain = &find_value("disable_plaintext_auth", $conf);
	print &ui_table_row($text{'ssl_plain'},
	    &ui_radio("plain", $plain,
		      [ @opts,
			[ '', &getdef("disable_plaintext_auth", \@opts) ] ]), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

