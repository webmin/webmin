#!/usr/local/bin/perl
# Show local LDAP server configuration options, from LDIF format config

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
&ui_print_header(undef, $text{'slapd_title'}, "", "slapd");
$conf = &get_ldif_config();
@tds = ( "width=30%" );

print &ui_form_start("save_ldif.cgi", "post");
print &ui_hidden_table_start($text{'slapd_header'}, "width=100%", 2,
			     "basic", 1,\@tds);

# Top-level DN
$defdb = &get_default_db();
$suffix = &find_ldif_value("olcSuffix", $conf, $defdb);
print &ui_table_row($text{'slapd_suffix'},
		    &ui_textbox('suffix', $suffix, 60));

# Admin login
$rootdn = &find_ldif_value("olcRootDN", $conf, $defdb);
print &ui_table_row($text{'slapd_rootdn'},
		    &ui_textbox('rootdn', $rootdn, 60));

# Admin password
$rootpw = &find_ldif_value("olcRootPW", $conf, $defdb);
if ($rootpw =~ /^{crypt}(.*)/i) {
	$rootmode = 1;
	$rootcrypt = $1;
	}
elsif ($rootpw =~ /^{sha1}(.*)/i) {
	$rootmode = 2;
	$rootsha1 = $1;
	}
elsif ($rootpw =~ /^{[a-z0-9]+}(.*)/i) {
	$rootmode = 3;
	$rootenc = $rootpw;
	}
else {
	$rootmode = 0;
	$rootplain = $rootpw;
	}

# Current password
print &ui_table_row($text{'slapd_rootpw'},
		    $rootmode == 1 ? &text('slapd_root1', $rootcrypt) :
		    $rootmode == 2 ? &text('slapd_root2', $rootsha1) :
		    $rootmode == 3 ? &text('slapd_root3', $rootenc) :
		    $rootplain eq '' ? $text{'slapd_noroot'} :
				     $rootplain);

# Set to new
print &ui_table_row($text{'slapd_rootchange'},
		    &ui_opt_textbox('rootchange', undef, 30,
			$text{'slapd_leave'}, $text{'slapd_set'}));

# Cache size
$dbcachesize = &find_ldif_value("olcDbCachesize", $conf, $defdb);
print &ui_table_row($text{'slapd_dbcachesize'},
	    &ui_opt_textbox("dbcachesize", $dbcachesize, 10, $text{'default'}));

# Size limit
$sizelimit = &find_ldif_value("olcSizeLimit", $conf, $defdb);
print &ui_table_row($text{'slapd_sizelimit'},
    &ui_opt_textbox('sizelimit', $sizelimit, 10, $text{'default'}." (500)"));

print &ui_hidden_table_end("basic");

# SSL section
print &ui_hidden_table_start($text{'slapd_header2'}, "width=100%", 2,
			     "ssl", 0, \@tds);

# Protocols to serve
if (&can_get_ldap_protocols()) {
	$protos = &get_ldap_protocols();
	@protos = sort { $a cmp $b } keys %$protos;
	print &ui_table_row($text{'slapd_protos'},
		&ui_select("protos",
			   [ grep { $protos->{$_} } @protos ],
			   [ map { [ $_, $text{'slapd_'.$_} ] } @protos ],
			   scalar(@protos), 1));
	}

# SSL file options
$anycert = 0;
$confdb = &get_config_db();
foreach $s ([ 'olcTLSCertificateFile', 'cert' ],
	    [ 'olcTLSCertificateKeyFile', 'key' ],
	    [ 'olcTLSCACertificateFile', 'ca' ]) {
	$cert = &find_ldif_value($s->[0], $conf, $confdb);
	print &ui_table_row($text{'slapd_'.$s->[1]},
		&ui_opt_textbox($s->[1], $cert, 50, $text{'slapd_none'}).
		&file_chooser_button($s->[1]));
	$anycert = 1 if ($cert);
	}

print &ui_hidden_table_end("ssl");
print &ui_form_end([ [ undef, $text{'save'} ] ]);

# SSL setup button
print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("gencert_form.cgi", $text{'slapd_gencert'},
		      $text{'slapd_gencertdesc'}.
		      ($anycert ? "<b>$text{'slapd_gencertwarn'}</b>" : ""));
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});

