#!/usr/local/bin/perl
# Show icons for LDAP server configuration options

require './ldap-server-lib.pl';

# Try to get OpenLDAP version
$ver = &get_ldap_server_version();
$vermsg = &text('index_version', $ver) if ($ver);

# Show title
&ui_print_header(undef, $module_info{'desc'}, "", "intro", 1, 1, 0,
		 undef, undef, undef, $vermsg);

# Is it installed and usable?
$local = &local_ldap_server();
if ($local == -1) {
	&ui_print_endpage(&text('index_eslapd', "<tt>$config{'slapd'}</tt>",
				"../config.cgi?$module_name"));
	}
elsif ($local == -2) {
	&ui_print_endpage(&text('index_econfig',
				"<tt>$config{'config_file'}</tt>",
				"../config.cgi?$module_name"));
	}
elsif ($local == 0) {
	# Can we connect?
	$ldap = &connect_ldap_db();
	if (!ref($ldap)) {
		&ui_print_endpage(&text('index_econnect', $ldap,
					"../config.cgi?$module_name"));
		}
	}

# Check if need to init new install
# XXX

# Work out icons
if ($local) {
	# All local server icons
	@pages = ( "slapd", "schema", "acl", "browser", "create" );
	}
else {
	# Just browser and DN creator?
	@pages = ( "browser", "create" );
	}
@pages = grep { $access{$_} } @pages;
@links = map { "edit_".$_.".cgi" } @pages;
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/$_.gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 5);

if ($local == 1) {
	# Show stop/restart buttons
	print "<hr>\n";
	print &ui_buttons_start();
	if (&is_ldap_server_running()) {
		print &ui_buttons_row("apply.cgi", $text{'index_apply'},
				      $text{'index_applydesc'});
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
				      $text{'index_stopdesc'});
		}
	else {
		print &ui_buttons_row("start.cgi", $text{'index_start'},
				      $text{'index_startdesc'});
		}

	# Start at boot button
	if (&foreign_check("init")) {
		$iname = $config{'init_name'} || $module_name;
		&foreign_require("init", "init-lib.pl");
		$st = &init::action_status($iname);
		print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
				      $text{'index_bootdesc'},
				      &ui_hidden("iname", $iname),
				      &ui_yesno_radio("boot",$st == 2 ? 1 : 0));
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});
