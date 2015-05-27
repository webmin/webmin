#!/usr/local/bin/perl
# edit_ssl.cgi
# Webserver SSL form

require './usermin-lib.pl';
&ui_print_header(undef, $text{'ssl_title'}, "");
&ReadParse();
&get_usermin_miniserv_config(\%miniserv);

# Show tabs
@tabs = map { [ $_, $text{'ssl_tab'.$_}, "edit_ssl.cgi?mode=$_" ] }
	    ( "ssl", "current", "ips", "create", "upload" );
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

# Basic SSL settings
print &ui_tabs_start_tab("mode", "ssl");
print $text{'ssl_desc1'},"<p>\n";
print $text{'ssl_desc2'},"<p>\n";

print &ui_form_start("change_ssl.cgi", "post");
print &ui_table_start($text{'ssl_header'}, undef, 2);

print &ui_table_row($text{'ssl_on'},
	&ui_yesno_radio("ssl", $miniserv{'ssl'}));

print &ui_table_row($text{'ssl_key'},
	&ui_textbox("key", $miniserv{'keyfile'}, 40)." ".
	&file_chooser_button("key"));

print &ui_table_row($text{'ssl_cert'},
	&ui_opt_textbox("cert", $miniserv{'certfile'}, 40,
			$text{'ssl_cert_def'}."<br>",$text{'ssl_cert_oth'})." ".
	&file_chooser_button("cert"));

print &ui_table_row($text{'ssl_redirect'},
	&ui_yesno_radio("ssl_redirect", $miniserv{'ssl_redirect'}));

print &ui_table_row($text{'ssl_version'},
	&ui_opt_textbox("version", $miniserv{'ssl_version'}, 4,
			$text{'ssl_auto'}));

print &ui_table_row($text{'ssl_deny'},
	&ui_checkbox("no_ssl2", 1, "SSLv2", $miniserv{'no_ssl2'})."\n".
	&ui_checkbox("no_ssl3", 1, "SSLv3", $miniserv{'no_ssl3'})."\n".
	ui_checkbox("no_tls1", 1, "TLSv1.0", $miniserv{'no_tls1'})."\n".
	ui_checkbox("no_tls1_1", 1, "TLSv1.1", $miniserv{'no_tls1_1'})."\n".
	ui_checkbox("no_tls1_2", 1, "TLSv1.2", $miniserv{'no_tls1_2'})."\n"
	);

print &ui_table_row($text{'ssl_compression'},
	&ui_yesno_radio("ssl_compression", !$miniserv{'no_sslcompression'}));

print &ui_table_row($text{'ssl_honorcipherorder'},
	&ui_yesno_radio("ssl_honorcipherorder",
			$miniserv{'ssl_honorcipherorder'}));

$clist = $miniserv{'ssl_cipher_list'};
$cmode = !$clist ? 1 :
	 $clist eq $webmin::strong_ssl_ciphers ? 2 :
	 $clist eq $webmin::pfs_ssl_ciphers ? 3 :
	 0;
print &ui_table_row($text{'ssl_cipher_list'},
	&ui_radio("cipher_list_def", $cmode,
		  [ [ 1, $text{'ssl_auto'}."<br>" ],
		    [ 2, $text{'ssl_strong'}."<br>" ],
		    [ 3, $text{'ssl_pfs'}."<br>" ],
		    [ 0, $text{'ssl_clist'}." ".
			 &ui_textbox("cipher_list",
				     $cmode == 0 ? $clist : "", 30) ] ]));

print &ui_table_row($text{'ssl_extracas'},
	&ui_textarea("extracas", join("\n",split(/\s+/, $miniserv{'extracas'})),
		     3, 60)." ".
	&file_chooser_button("extracas", 0, undef, undef, 1));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);
print &ui_tabs_end_tab();

# Page showing current cert
print &ui_tabs_start_tab("mode", "current");
print "$text{'ssl_current'}<p>\n";
print &ui_table_start($text{'ssl_cheader'}, undef, 4);
$info = &webmin::cert_info($miniserv{'certfile'} || $miniserv{'keyfile'});
foreach $i ('cn', 'o', 'email', 'issuer_cn', 'issuer_o', 'issuer_email',
	    'notafter', 'type') {
	if ($info->{$i}) {
		print &ui_table_row($text{'ca_'.$i}, $info->{$i});
		}
	}
@clinks = (
	&ui_link("download_cert.cgi/cert.pem", $text{'ssl_pem'}),
	&ui_link("download_cert.cgi/cert.p12", $text{'ssl_pkcs12'})
	);
print &ui_table_row($text{'ssl_download'}, &ui_links_row(\@clinks));
print &ui_table_end();
print &ui_tabs_end_tab();

# Table listing per-IP SSL certs
print &ui_tabs_start_tab("mode", "ips");
print "$text{'ssl_ipkeys'}<p>\n";
@ipkeys = &webmin::get_ipkeys(\%miniserv);
if (@ipkeys) {
	print &ui_columns_start([ $text{'ssl_ips'}, $text{'ssl_key'},
				  $text{'ssl_cert'} ]);
	foreach $k (@ipkeys) {
		print &ui_columns_row([
			&ui_link("edit_ipkey.cgi?idx=$k->{'index'}",
				 join(", ", @{$k->{'ips'}})),
			"<tt>$k->{'key'}</tt>",
			$k->{'cert'} ? "<tt>$k->{'cert'}</tt>"
				     : $text{'ssl_cert_def'},
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'ssl_ipkeynone'}</b><p>\n";
	}
print &ui_link("edit_ipkey.cgi?new=1", $text{'ssl_addipkey'}),"<p>\n";
print &ui_tabs_end_tab();

# SSL key generation form
print &ui_tabs_start_tab("mode", "create");
print "$text{'ssl_newkey'}<p>\n";
my $curkey = &read_file_contents($miniserv{'keyfile'});
my $origkey = &read_file_contents("$root_directory/miniserv.pem");
if ($curkey eq $origkey) {
	# System is using the original (insecure) Webmin key!
	print "<b>$text{'ssl_hole'}</b><p>\n";
	}

print &ui_form_start("newkey.cgi");
print &ui_table_start($text{'ssl_header1'}, undef, 2);

$host = $ENV{'HTTP_HOST'};
$host =~ s/:.*//;
print &webmin::show_ssl_key_form($host, undef, 
			 "Usermin Webserver on ".&get_system_hostname());

print &ui_table_row($text{'ssl_newfile'},
	    &ui_textbox("newfile", "$config{'usermin_dir'}/miniserv.pem", 40));

print &ui_table_row($text{'ssl_usenew'},
		    &ui_yesno_radio("usenew", 1));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'ssl_create'} ] ]);
print &ui_tabs_end_tab();

# SSL key upload form
print &ui_tabs_start_tab("mode", "upload");
print "$text{'ssl_savekey'}<p>\n";
print &ui_form_start("savekey.cgi", "form-data");
print &ui_table_start($text{'ssl_saveheader'}, undef, 2);

print &ui_table_row($text{'ssl_privkey'},
		    &ui_textarea("key", undef, 7, 70)."<br>\n".
		    "<b>$text{'ssl_upload'}</b>\n".
		    &ui_upload("keyfile"));

print &ui_table_row($text{'ssl_privcert'},
		    &ui_radio("cert_def", 1,
			[ [ 1, $text{'ssl_same'} ],
			  [ 0, $text{'ssl_below'} ] ])."<br>\n".
		    &ui_textarea("cert", undef, 7, 70)."<br>\n".
		    "<b>$text{'ssl_upload'}</b>\n".
		    &ui_upload("certfile"));

print &ui_table_row($text{'ssl_privchain'},
		    &ui_radio("chain_def", 1,
			[ [ 1, $miniserv{'extracas'} ? $text{'ssl_leavechain'}
						     : $text{'ssl_nochain'} ],
			  [ 0, $text{'ssl_below'} ] ])."<br>\n".
		    &ui_textarea("chain", undef, 7, 70)."<br>\n".
		    "<b>$text{'ssl_upload'}</b>\n".
		    &ui_upload("chainfile"));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

# Button to copy cert from Webmin
&get_miniserv_config(\%wminiserv);
if ($wminiserv{'ssl'}) {
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("copycert.cgi", $text{'ssl_copycert'},
			      $text{'ssl_copycertdesc'});
	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'index_return'});

