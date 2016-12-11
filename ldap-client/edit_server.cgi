#!/usr/local/bin/perl
# Show a form for editing the LDAP server to connect to

require './ldap-client-lib.pl';
&ui_print_header(undef, $text{'server_title'}, "", "server");

$conf = &get_config();
print &ui_form_start("save_server.cgi", "post");
print &ui_table_start($text{'server_header'}, "width=100%", 2);

$uri = &find_svalue("uri", $conf);
if ($uri) {
	# Show LDAP servers as URIs
	$utable = &ui_columns_start([
			$text{'server_uhost'},
			$text{'server_uport'},
			$text{'server_uproto'} ]);
	$i = 0;
	foreach $u (split(/\s+/, $uri), undef) {
		local ($proto, $host, $port);
		if ($u =~ /^(ldap|ldaps|ldapi):\/\/([a-z0-9\_\-\.]+)(:(\d+))?/) {
			($proto, $host, $port) = ($1, $2, $4);
			}
		$utable .= &ui_columns_row([
		    &ui_textbox("uhost_$i", $host, 20),
		    &ui_opt_textbox("uport_$i", $port, 5, $text{'default'}),
		    &ui_select("uproto_$i", $proto,
			       [ [ 'ldap', $text{'server_ldap'} ],
				 [ 'ldaps', $text{'server_ldaps'} ],
				 [ 'ldapi', $text{'server_ldapi'} ] ]),
		    ]);
		$i++;
		}
	$utable .= &ui_columns_end();
	print &ui_table_row($text{'server_uri'}, $utable);
	}
else {
	# Show LDAP servers from host and port
	print &ui_table_row($text{'server_host'},
		&ui_textarea("host", join("\n", split(/\s+/,
				  &find_svalue("host", $conf))), 3, 50));

	print &ui_table_row($text{'server_port'},
		&ui_opt_textbox("port", &find_svalue("port", $conf), 5,
				$text{'default'}));
	}

print &ui_table_row($text{'server_version'},
	&ui_radio("version", &find_svalue("ldap_version", $conf),
		  [ [ "", $text{'default'} ],
		    [ 1, "V1" ], [ 2, "V2" ], [ 3, "V3" ] ]));

print &ui_table_row($text{'server_timelimit'},
	&ui_opt_textbox("timelimit", &find_svalue("bind_timelimit", $conf), 5,
		 	$text{'default'})." ".$text{'base_secs'});

print &ui_table_row($text{'server_binddn'},
	&ui_opt_textbox("binddn", &find_svalue("binddn", $conf), 40,
			$text{'server_anon'}));

print &ui_table_row($text{'server_bindpw'},
	&ui_opt_textbox("bindpw", &find_svalue("bindpw", $conf), 20,
			$text{'server_none'}));

my $rootbindbn = &find_svalue("rootpwmoddn", $conf, 2) ?
			&find_svalue("rootpwmoddn", $conf) :
			&find_svalue("rootbinddn", $conf);
print &ui_table_row($text{'server_rootbinddn'},
	&ui_opt_textbox("rootbinddn", $rootbindbn, 40, $text{'server_same'}));

my $rootsecret = &find_svalue("rootpwmoddn", $conf, 2) ?
			&find_svalue("rootpwmodpw", $conf) :
			&get_rootbinddn_secret();
print &ui_table_row($text{'server_rootbindpw'},
	&ui_opt_textbox("rootbindpw", $rootsecret, 20,
			$text{'server_none'}));

# SSL options
print &ui_table_hr();

$ssl = &find_svalue("ssl", $conf);
$ssl = "" if ($ssl eq "no");
print &ui_table_row($text{'server_ssl'},
	&ui_radio("ssl", &find_svalue("ssl", $conf),
		  [ [ "yes", $text{'yes'} ],
		    [ "start_tls", $text{'server_tls'} ],
		    [ "", $text{'no'} ] ]));

print &ui_table_row($text{'server_peer'},
	&ui_radio("peer", &find_svalue("tls_checkpeer", $conf),
		  [ [ "", &text('server_def', $text{'no'}) ],
		    [ "yes", $text{'yes'} ],
		    [ "no", $text{'no'} ] ]));

print &ui_table_row($text{'server_cacert'},
	&ui_opt_textbox("cacert", &find_svalue("tls_cacertfile", $conf),
			40, $text{'server_none'})." ".
	&file_chooser_button("cacert"));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


