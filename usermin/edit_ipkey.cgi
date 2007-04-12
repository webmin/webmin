#!/usr/local/bin/perl
# Show an IP-specific SSL key

require './usermin-lib.pl';
&ReadParse();
&get_usermin_miniserv_config(\%miniserv);
if ($in{'new'}) {
	&ui_print_header(undef, $webmin::text{'ipkey_title1'}, "");
	}
else {
	&ui_print_header(undef, $webmin::text{'ipkey_title2'}, "");
	@ipkeys = &webmin::get_ipkeys(\%miniserv);
	$ipkey = $ipkeys[$in{'idx'}];
	}

print &ui_form_start("save_ipkey.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_table_start($webmin::text{'ipkey_header'}, undef, 2);

print &ui_table_row($webmin::text{'ipkey_ips'},
		    &ui_textarea("ips", join("\n", @{$ipkey->{'ips'}}),
				 3, 20));

print &ui_table_row($webmin::text{'ssl_key'},
		    &ui_textbox("key", $ipkey->{'key'}, 40)."\n".
		    &file_chooser_button("key"));

print &ui_table_row($webmin::text{'ssl_cert'},
		    &ui_opt_textbox("cert", $ipkey->{'cert'}, 40,
				$webmin::text{'ssl_cert_def'})."\n".
		    &file_chooser_button("cert"));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("edit_ssl.cgi", $webmin::text{'ssl_return'});

