#!/usr/local/bin/perl
# conf_smb.cgi
# Display Windows networking options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcs'}") unless $access{'conf_smb'};

&ui_print_header(undef, $text{'smb_title'}, "");

&get_share("global");

print &ui_form_start("save_smb.cgi", "post");
print &ui_table_start($text{'smb_title'}, undef, 2);

print &ui_table_row($text{'smb_workgroup'},
	&ui_opt_textbox("workgroup", &getval("workgroup"), 20,
			$text{'default'}));

$wmode = &isfalse("wins support") && &getval("wins server") eq "" ? 2 :
	 &getval("wins server") ne "" ? 1 : 0;
print &ui_table_row($text{'smb_wins'},
	&ui_radio("wins", $wmode,
		  [ [ 0, $text{'smb_winsserver'} ],
		    [ 1, $text{'smb_useserver'}." ".
		 	&ui_textbox("wins_server", &getval("wins server"),20) ],
		    [ 2, $text{'config_neither'} ] ]));

$desc = &getval("server string");
print &ui_table_row($text{'smb_description'},
	&ui_radio("server_string_def", !defined($desc) ? 1 :
				     $desc eq "" ? 2 : 0,
		[ [ 1, $text{'default'} ],
		  [ 2, $text{'smb_descriptionnone'} ],
		  [ 0, &ui_textbox("server_string", $desc, 40) ] ]));

print &ui_table_row($text{'smb_name'},
	&ui_textbox("netbios_name", &getval("netbios name"), 20));

print &ui_table_row($text{'smb_aliase'},
	&ui_textbox("netbios_aliases", &getval("netbios aliases"), 30));

print &ui_table_row($text{'smb_default'},
	&ui_select("default",  &getval("default"),
		   [ [ "", $text{'config_none'} ],
		     (grep { &can('r', \%access, $_) }
			   &list_shares()) ]));

print &ui_table_row($text{'smb_show'},
	&ui_select("auto_services", [ split(/s\+/, &getval("auto services")) ],
		   [ grep { &can('r', \%access, $_) }
                           &list_shares() ],
		   1, 5));

print &ui_table_row($text{'smb_disksize'},
	&ui_opt_textbox("max_disk_size", &getval("max disk size"), 6,
			$text{'smb_unlimited'})." kB");

print &ui_table_row($text{'smb_winpopup'},
	&ui_textbox("message_command", &getval("message command"), 40));

print &ui_table_row($text{'smb_priority'},
	&ui_textbox("os_level", &getval("os level"), 6));

print &ui_table_row($text{'smb_protocol'},
	&ui_select("protocol", &getval("protocol"),
		   [ [ "", $text{'default'} ],
		     @protocols ]));

print &ui_table_row($text{'smb_master'},
	&ui_radio("preferred_master",
		  &istrue("preferred master") ? "yes" :
		  &isfalse("preferred master") ? "no" :
		  &getval("preferred master") =~ /auto/ ||
		   !&getval("preferred master") ? "auto" : "",
		  [ [ "yes", $text{'yes'} ],
		    [ "no", $text{'no'} ],
		    [ "auto", $text{'smb_master_auto'} ] ]));

$security = &getval("security");
print &ui_table_row($text{'smb_security'},
	&ui_select("security", $security,
		   [ [ "", $text{'default'} ],
		     map { [ $_, $text{'smb_'.$_.'level'} ||
				 $text{'smb_'.$_} ] }
			 ( "share", "user", "server", "domain", "ads" ) ],
		   1, 0, 1));

print &ui_table_row($text{'smb_passwdserver'},
	&ui_textbox("password_server", &getval("password server"), 20));

$ra = &getval("remote announce");
$atable = &ui_radio("remote_def", $ra ? 0 : 1,
		    [ [ 1, $text{'smb_nowhere'} ],
		      [ 0, $text{'smb_fromlist'} ] ])."<br>\n";
$atable .= &ui_columns_start([ $text{'smb_ip'}, $text{'smb_asworkgroup'} ]);
@rem = split(/\s+/, $ra);
$len = @rem ? @rem+1 : 2;
for($i=0; $i<$len; $i++) {
	if ($rem[$i] =~ /^([\d\.]+)\/(.+)$/) { $ip = $1; $wg = $2; }
	elsif ($rem[$i] =~ /^([\d\.]+)$/) { $ip = $1; $wg = ""; }
	else { $ip = $wg = ""; }
	$atable .= &ui_columns_row([
		&ui_textbox("remote_ip$i", $ip, 15),
		&ui_textbox("remote_wg$i", $wg, 20),
		]);
	}
$atable .= &ui_columns_end();
print &ui_table_row($text{'smb_announce'}, $atable);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

