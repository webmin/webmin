#!/usr/local/bin/perl
# edit_ssl.cgi
# Webserver SSL form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'ssl_title'}, "");
&ReadParse();
&get_miniserv_config(\%miniserv);

# Check if we even *have* SSL support
$@ = undef;
eval "use Net::SSLeay";
if ($@) {
	print &text('ssl_essl', "http://www.webmin.com/ssl.html"),"<p>\n";
	if (&foreign_available("cpan")) {
		print &text('ssl_cpan', "../cpan/download.cgi?source=3&cpan=Net::SSLeay&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
		}
	$err = $@;
	$err =~ s/\s+at.*line\s+\d+[\000-\377]*$//;
	print &text('ssl_emessage', "<tt>$err</tt>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Show tabs
@tabs = map { [ $_, $text{'ssl_tab'.$_}, "edit_upgrade.cgi?mode=$_" ] }
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

$clist = $miniserv{'ssl_cipher_list'};
$cmode = !$clist ? 1 :
	 $clist eq $strong_ssl_ciphers ? 2 : 0;
print &ui_table_row($text{'ssl_cipher_list'},
	&ui_radio("cipher_list_def", $cmode,
		  [ [ 1, $text{'ssl_auto'}."<br>" ],
		    [ 2, $text{'ssl_strong'}."<br>" ],
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
$info = &cert_info($miniserv{'certfile'} || $miniserv{'keyfile'});
foreach $i ('cn', 'o', 'email', 'issuer_cn', 'issuer_o', 'issuer_email',
	    'notafter', 'type') {
	if ($info->{$i}) {
		print &ui_table_row($text{'ca_'.$i}, $info->{$i});
		}
	}
@clinks = (
	"<a href='download_cert.cgi/cert.pem'>".
	"$text{'ssl_pem'}</a>",
	"<a href='download_cert.cgi/cert.p12'>".
	"$text{'ssl_pkcs12'}</a>"
	);
print &ui_table_row($text{'ssl_download'}, &ui_links_row(\@clinks));
print &ui_table_end();
print &ui_tabs_end_tab();

# Table listing per-IP SSL certs
print &ui_tabs_start_tab("mode", "ips");
print "$text{'ssl_ipkeys'}<p>\n";
@ipkeys = &get_ipkeys(\%miniserv);
if (@ipkeys) {
	print &ui_columns_start([ $text{'ssl_ips'}, $text{'ssl_key'},
				  $text{'ssl_cert'} ]);
	foreach $k (@ipkeys) {
		print &ui_columns_row([
			"<a href='edit_ipkey.cgi?idx=$k->{'index'}'>".
			join(", ", @{$k->{'ips'}})."</a>",
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
print "<a href='edit_ipkey.cgi?new=1'>$text{'ssl_addipkey'}</a><p>\n";
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
print &show_ssl_key_form($host, undef, 
			 "Webmin Webserver on ".&get_system_hostname());

print &ui_table_row($text{'ssl_newfile'},
	    &ui_textbox("newfile", "$config_directory/miniserv.pem", 40));

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

&ui_print_footer("", $text{'index_return'});

