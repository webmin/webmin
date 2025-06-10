#!/usr/local/bin/perl
# Show an IP-specific SSL key

require './webmin-lib.pl';
&ReadParse();
&get_miniserv_config(\%miniserv);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'ipkey_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'ipkey_title2'}, "");
	@ipkeys = &get_ipkeys(\%miniserv);
	$ipkey = $ipkeys[$in{'idx'}];
	}

print &ui_form_start("save_ipkey.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_table_start($text{'ipkey_header'}, undef, 2);

print &ui_table_row($text{'ipkey_ips2'},
		    &ui_textarea("ips", join("\n", @{$ipkey->{'ips'}}),
				 3, 60));

print &ui_table_row($text{'ssl_key'},
		    &ui_textbox("key", $ipkey->{'key'}, 40)."\n".
		    &file_chooser_button("key"), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ssl_cert'},
		    &ui_opt_textbox("cert", $ipkey->{'cert'}, 40,
				$text{'ssl_cert_def'})."&nbsp;".
		    &file_chooser_button("cert"), undef, [ "valign=middle","valign=middle" ]);

$mode = $ipkey->{'extracas'} eq "none" ? 2 :
	$ipkey->{'extracas'} ? 1 : 0;
print &ui_table_row($text{'ssl_extracas'},
	&ui_radio("extracas_mode", $mode,
		  [ [ 0, $text{'ssl_extracasdef'} ],
		    [ 2, $text{'ssl_extracasnone'} ],
		    [ 1, $text{'ssl_extracasbelow'} ] ])."<br>\n".
	&ui_textarea("extracas",
		     $mode == 1 ? join("\n",split(/\s+/, $ipkey->{'extracas'}))
				: "",
		     3, 60)." ".
	"<br>".&file_chooser_button("extracas", 0, undef, undef, 1));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("edit_ssl.cgi", $text{'ssl_return'});

