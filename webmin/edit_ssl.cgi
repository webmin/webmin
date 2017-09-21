#!/usr/bin/perl
# Webserver SSL form

use strict;
use warnings;

require "./webmin-lib.pl";

# Globals
our %text;
our %miniserv;
our %in;
our $config_directory;
our $module_name;
our $strong_ssl_ciphers;
our $pfs_ssl_ciphers;
our $info;
our $root_directory;
our %config;

ui_print_header(undef, $text{'ssl_title'}, "");
ReadParse();
get_miniserv_config(\%miniserv);

# Check if we even *have* SSL support
$@ = undef;
eval "use Net::SSLeay";
if ($@) {
	print text('ssl_essl', "http://www.webmin.com/ssl.html"),"<p>\n";
	if (foreign_available("cpan")) {
		print text('ssl_cpan', "../cpan/download.cgi?source=3&cpan=Net::SSLeay&mode=2&return=/$module_name/&returndesc=".urlize($text{'index_return'})),"<p>\n";
		}
	my $err = $@;
	$err =~ s/\s+at.*line\s+\d+[\000-\377]*$//;
	print text('ssl_emessage', "<tt>$err</tt>"),"<p>\n";
	ui_print_footer("", $text{'index_return'});
	exit;
	}

# Show tabs
my @tabs = map { [ $_, $text{'ssl_tab'.$_}, "edit_ssl.cgi?mode=$_" ] }
	    ( "ssl", "current", "ips", "create", "csr", "upload", "lets" );
print ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

# Basic SSL settings
print ui_tabs_start_tab("mode", "ssl");
print $text{'ssl_desc1'},"<p>\n";
print $text{'ssl_desc2'},"<p>\n";

print ui_form_start("change_ssl.cgi", "post");
print ui_table_start($text{'ssl_header'}, undef, 2);

print ui_table_row($text{'ssl_on'},
	ui_yesno_radio("ssl", $miniserv{'ssl'}));

print ui_table_row($text{'ssl_key'},
	ui_textbox("key", $miniserv{'keyfile'}, 40)." ".
	file_chooser_button("key"));

print ui_table_row($text{'ssl_cert'},
	ui_opt_textbox("cert", $miniserv{'certfile'}, 40,
			$text{'ssl_cert_def'}."<br>",$text{'ssl_cert_oth'})." ".
	file_chooser_button("cert"));

print ui_table_row($text{'ssl_redirect'},
	ui_yesno_radio("ssl_redirect", $miniserv{'ssl_redirect'}));

print ui_table_row($text{'ssl_version'},
	ui_opt_textbox("version", $miniserv{'ssl_version'}, 4,
			$text{'ssl_auto'}));

print ui_table_row($text{'ssl_deny'},
	ui_checkbox("no_ssl2", 1, "SSLv2", $miniserv{'no_ssl2'})."\n".
	ui_checkbox("no_ssl3", 1, "SSLv3", $miniserv{'no_ssl3'})."\n".
	ui_checkbox("no_tls1", 1, "TLSv1.0", $miniserv{'no_tls1'})."\n".
	ui_checkbox("no_tls1_1", 1, "TLSv1.1", $miniserv{'no_tls1_1'})."\n".
	ui_checkbox("no_tls1_2", 1, "TLSv1.2", $miniserv{'no_tls1_2'})."\n"
	);

print ui_table_row($text{'ssl_compression'},
	ui_yesno_radio("ssl_compression", !$miniserv{'no_sslcompression'}));

print ui_table_row($text{'ssl_honorcipherorder'},
	ui_yesno_radio("ssl_honorcipherorder",
			$miniserv{'ssl_honorcipherorder'}));

my $clist = $miniserv{'ssl_cipher_list'};
my $cmode = !$clist ? 1 :
	 $clist eq $strong_ssl_ciphers ? 2 :
	 $clist eq $pfs_ssl_ciphers ? 3 :
	 0;
print ui_table_row($text{'ssl_cipher_list'},
	ui_radio("cipher_list_def", $cmode,
		  [ [ 1, $text{'ssl_auto'}."<br>" ],
		    [ 2, $text{'ssl_strong'}."<br>" ],
		    [ 3, $text{'ssl_pfs'}."<br>" ],
		    [ 0, $text{'ssl_clist'}." ".
			 ui_textbox("cipher_list",
				     $cmode == 0 ? $clist : "", 50) ] ]));
my $extracas;
if (defined $miniserv{'extracas'}) { $extracas = $miniserv{'extracas'}; }
else { $extracas = ""; }
print ui_table_row($text{'ssl_extracas'},
	ui_textarea("extracas", join("\n",split(/\s+/, $extracas)),
		     3, 60)." ".
	"<br>".file_chooser_button("extracas", 0, undef, undef, 1));

print ui_table_end();
print ui_form_end([ [ "", $text{'save'} ] ]);
print ui_tabs_end_tab();

# Page showing current cert
print ui_tabs_start_tab("mode", "current");
print "$text{'ssl_current'}<p>\n";
print ui_table_start($text{'ssl_cheader'}, undef, 4);
$info = cert_info($miniserv{'certfile'} || $miniserv{'keyfile'});
foreach my $i ('cn', 'alt', 'o', 'email', 'issuer_cn', 'issuer_o', 'issuer_email',
	       'notafter', 'type') {
	if ($info->{$i}) {
		print ui_table_row($text{'ca_'.$i},
			ref($info->{$i}) ? join(", ", @{$info->{$i}}) : $info->{$i});
		}
	}
my @clinks = (
	ui_link("download_cert.cgi/cert.pem", $text{'ssl_pem'}),
	ui_link("download_cert.cgi/cert.p12", $text{'ssl_pkcs12'})
	);
print ui_table_row($text{'ssl_download'}, &ui_links_row(\@clinks));
print ui_table_end();
print ui_tabs_end_tab();

# Table listing per-IP / domain SSL certs
print ui_tabs_start_tab("mode", "ips");
print "$text{'ssl_ipkeys'}<p>\n";
my @ipkeys = get_ipkeys(\%miniserv);
if (@ipkeys) {
	print ui_columns_start([ $text{'ssl_ips'},
				 $text{'ssl_key'},
				 $text{'ssl_cert'} ]);
	foreach my $k (@ipkeys) {
		print ui_columns_row([
			ui_link("edit_ipkey.cgi?idx=".$k->{'index'},
			join(", ", @{$k->{'ips'}}) ),
			"<tt>$k->{'key'}</tt>",
			$k->{'cert'} ? "<tt>$k->{'cert'}</tt>"
				     : $text{'ssl_cert_def'},
			]);
		}
	print ui_columns_end();
	}
else {
	print "<b>$text{'ssl_ipkeynone'}</b><p>\n";
	}
print ui_link("edit_ipkey.cgi?new=1", $text{'ssl_addipkey'});
print "<p>\n";
print ui_tabs_end_tab();

# SSL key generation form
print ui_tabs_start_tab("mode", "create");
print "$text{'ssl_newkey'}<p>\n";
my $curkey = read_file_contents($miniserv{'keyfile'});
my $origkey = read_file_contents("$root_directory/miniserv.pem");
if ($curkey eq $origkey) {
	# System is using the original (insecure) Webmin key!
	print "<b>$text{'ssl_hole'}</b><p>\n";
	}

print ui_form_start("newkey.cgi");
print ui_table_start($text{'ssl_header1'}, undef, 2);

my $host = $ENV{'HTTP_HOST'};
$host =~ s/:.*//;
print show_ssl_key_form($host, undef, 
			 "Webmin Webserver on ".get_system_hostname());

print ui_table_row($text{'ssl_newfile'},
	    ui_textbox("newfile", "$config_directory/miniserv.pem", 40));

print ui_table_row($text{'ssl_usenew'},
		    ui_yesno_radio("usenew", 1));

print ui_table_end();
print ui_form_end([ [ "", $text{'ssl_create'} ] ]);
print ui_tabs_end_tab();

# SSL CSR generation form
my $keydata = read_file_contents("$config_directory/miniserv.newkey");
my $csrdata = read_file_contents("$config_directory/miniserv.csr");
print ui_tabs_start_tab("mode", "csr");
print "$text{'ssl_newcsr'}<p>\n";

print ui_form_start("newcsr.cgi");
print ui_table_start($text{'ssl_header2'}, undef, 2);

print show_ssl_key_form($host, undef, 
			 "Webmin Webserver on ".get_system_hostname());

print ui_table_row($text{'ssl_newfile'},
	    ui_textbox("newfile", "$config_directory/miniserv.newkey", 40));

print ui_table_row($text{'ssl_csrfile'},
	    ui_textbox("csrfile", "$config_directory/miniserv.csr", 40));

print ui_table_end();
print ui_form_end([ [ "", $text{'ssl_create'} ] ]);

if ($keydata) {
	# Show most recent CSR and key
	print "<p>\n";
	print ui_hidden_start($text{'ssl_csralready'}, "already", 0);
	print $text{'ssl_already1'},"<p>\n";
	print "<pre>".html_escape($keydata)."</pre>\n";
	print $text{'ssl_already2'},"<p>\n";
	print "<pre>".html_escape($csrdata)."</pre>\n";
	print ui_hidden_end("already");
	}

print ui_tabs_end_tab();

# SSL key upload form
print ui_tabs_start_tab("mode", "upload");
print "$text{'ssl_savekey'}<p>\n";
print ui_form_start("savekey.cgi", "form-data");
print ui_table_start($text{'ssl_saveheader'}, undef, 2);

print ui_table_row($text{'ssl_privkey'},
		    ui_textarea("key", $keydata, 7, 70)."<br>\n".
		    "<b>$text{'ssl_upload'}</b>\n".
		    ui_upload("keyfile").
		    ($keydata ? "<br>".$text{'ssl_fromcsr'} : ""));

print ui_table_row($text{'ssl_privcert'},
		    ui_radio("cert_def", 1,
			[ [ 1, $text{'ssl_same'} ],
			  [ 0, $text{'ssl_below'} ] ])."<br>\n".
		    ui_textarea("cert", undef, 7, 70)."<br>\n".
		    "<b>$text{'ssl_upload'}</b>\n".
		    ui_upload("certfile"));

print ui_table_row($text{'ssl_privchain'},
		    ui_radio("chain_def", 1,
			[ [ 1, $miniserv{'extracas'} ? $text{'ssl_leavechain'}
						     : $text{'ssl_nochain'} ],
			  [ 0, $text{'ssl_below'} ] ])."<br>\n".
		    ui_textarea("chain", undef, 7, 70)."<br>\n".
		    "<b>$text{'ssl_upload'}</b>\n".
		    ui_upload("chainfile"));

print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);
print ui_tabs_end_tab();

# Let's Encrypt form
print ui_tabs_start_tab("mode", "lets");
print "$text{'ssl_letsdesc'}<p>\n";

my $err = &check_letsencrypt();
if ($err) {
	print "<b>",&text('ssl_letserr', $err),"</b><p>\n";
	print &text('ssl_letserr2', "../config.cgi?$module_name"),"<p>\n";
	}
else {
	# Show form to create a cert
	print "$text{'ssl_letsdesc2'}<p>\n";
	print &ui_form_start("letsencrypt.cgi");
	print &ui_table_start($text{'ssl_letsheader'}, undef, 2);

	# For domain names
	my @doms = $config{'letsencrypt_doms'} ?
			split(/\s+/, $config{'letsencrypt_doms'}) : ( $host );
	print &ui_table_row($text{'ssl_letsdoms'},
		&ui_textarea("dom", join("\n", @doms), 5, 40));

	# Apache vhost or other path
	my @opts;

	my $webroot = $config{'letsencrypt_webroot'};
	my $mode = $webroot eq 'dns' ? 3 : $webroot ? 2 : 0;
	if (&foreign_installed("apache")) {
		&foreign_require("apache");
		my $conf = &apache::get_config();
		my @snames;
		foreach my $virt (&apache::find_directive_struct(
					"VirtualHost", $conf)) {
			my $sn = &apache::find_directive(
				"ServerName", $virt->{'members'});
			push(@snames, [ $sn,
					$sn || "&lt;".$text{'default'}."&gt;" ]);
			}
		my %done;
		@snames = grep { !$done{$_->[0]}++ } @snames;
		if (@snames) {
			@snames = sort { $a->[0] cmp $b->[0] } @snames;
			push(@opts, [ 0, $text{'ssl_webroot0'} ]);
			push(@opts, [ 1, $text{'ssl_webroot1'},
				      &ui_select("vhost", undef, \@snames) ]);
			}
		}
	push(@opts, [ 2, $text{'ssl_webroot2'},
		      &ui_textbox("webroot", $webroot, 40) ]);
	push(@opts, [ 3, $text{'ssl_webroot3'} ]);
	print &ui_table_row($text{'ssl_webroot'},
		&ui_radio_table("webroot_mode", $mode, \@opts));

	# Install in Webmin now?
	print &ui_table_row($text{'ssl_usewebmin'},
		&ui_yesno_radio("use", 1));

	# SSL key size
	print &ui_table_row($text{'ssl_size'},
		&ui_opt_textbox("size", undef, 6, $text{'default'}).
				" ".$text{'ssl_bits'});

	# Staging mode
	print &ui_table_row($text{'ssl_staging'},
		&ui_radio("staging", 0,
			  [ [ 0, $text{'ssl_staging0'} ],
			    [ 1, $text{'ssl_staging1'} ] ]));

	# Renewal option
	my $job = &find_letsencrypt_cron_job();
	my $renew = $job && $job->{'months'} =~ /^\*\/(\d+)$/ ? $1 : undef;
	print &ui_table_row($text{'ssl_letsrenew'},
		&ui_opt_textbox("renew", $renew, 4, $text{'ssl_letsnotrenew'}));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'ssl_letsok'} ],
			     [ 'save', $text{'ssl_letsonly'} ] ]);
	}

print ui_tabs_end_tab();

print ui_tabs_end(1);

ui_print_footer("", $text{'index_return'});

