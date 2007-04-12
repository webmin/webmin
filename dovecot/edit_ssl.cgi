#!/usr/local/bin/perl
# Show SSL options

require './dovecot-lib.pl';
&ui_print_header(undef, $text{'ssl_title'}, "");
$conf = &get_config();

print &ui_form_start("save_ssl.cgi", "post");
print &ui_table_start($text{'ssl_header'}, "width=100%", 4);

# SSL cert and key files
$cert = &find_value("ssl_cert_file", $conf);
print &ui_table_row($text{'ssl_cert'},
	    &ui_opt_textbox("cert", $cert, 40, &getdef("ssl_cert_file")), 3,
	    [ undef, "nowrap" ]);

$key = &find_value("ssl_key_file", $conf);
print &ui_table_row($text{'ssl_key'},
	    &ui_opt_textbox("key", $key, 40, &getdef("ssl_key_file")), 3,
	    [ undef, "nowrap" ]);

# Parameter regen time
$regen = &find_value("ssl_parameters_regenerate", $conf);
print &ui_table_row($text{'ssl_regen'},
		    &ui_opt_textbox("regen", $regen, 5,
				    &getdef("ssl_parameters_regenerate")).
				    " ".$text{'ssl_hours'}, 3);

# Disable plaintext passwords when not SSL
@opts = ( [ 'yes', $text{'yes'} ], [ 'no', $text{'no'} ] );
$plain = &find_value("disable_plaintext_auth", $conf);
print &ui_table_row($text{'ssl_plain'},
    &ui_radio("plain", $plain,
	      [ @opts,
		[ '', &getdef("disable_plaintext_auth", \@opts) ] ]), 3);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

