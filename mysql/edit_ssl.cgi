#!/usr/local/bin/perl
# Show a form to setup SSL

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'cnf_ecannot'});
&ui_print_header(undef, $text{'ssl_title'}, "", "ssl");

# Make sure config exists
$conf = &get_mysql_config();
if (!$conf) {
	print &text('cnf_efile', "<tt>$config{'my_cnf'}</tt>",
		    "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
($mysqld) = grep { $_->{'name'} eq 'mysqld' } @$conf;
$mysqld || &error($text{'cnf_emysqld'});
$mems = $mysqld->{'members'};

print &ui_form_start("save_ssl.cgi", "post");
print &ui_table_start($text{'ssl_header'}, "width=100%", 2);

# SSL cert file
$cert = &find_value("ssl_cert", $mems);
print &ui_table_row($text{'ssl_cert'},
		    &ui_opt_textbox("cert", $cert, 80, $text{'ssl_none'}).
		    &file_chooser_button("cert"));

# SSL key file
$key = &find_value("ssl_key", $mems);
print &ui_table_row($text{'ssl_key'},
		    &ui_opt_textbox("key", $key, 80, $text{'ssl_none'}).
		    &file_chooser_button("key"));

# SSL CA file
$ca = &find_value("ssl_ca", $mems);
print &ui_table_row($text{'ssl_ca'},
		    &ui_opt_textbox("ca", $ca, 80, $text{'ssl_none'}).
		    &file_chooser_button("ca"));

# SSL mandatory?
$req = &find_value("require_secure_transport", $mems);
print &ui_table_row($text{'ssl_req'},
		    &ui_yesno_radio("req", $req && lc($req) eq 'on'));

print &ui_table_end();
my @buts = ( [ "save", $text{'save'} ],
	     [ "restart", $text{'cnf_restart'} ] );
if (!$cert && !$key) {
	push(@buts, [ "gen", $text{'ssl_gen'} ]);
	}
print &ui_form_end(\@buts);
		     

&ui_print_footer("", $text{'index_return'});

