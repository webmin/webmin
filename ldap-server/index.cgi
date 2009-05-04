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
	# Expected, but not installed
	print &text('index_eslapd', "<tt>$config{'slapd'}</tt>",
				"../config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link("openldap",
			$text{'index_openldap'},
			"../$module_name/", $module_info{'desc'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	return;
	}
elsif ($local == -2) {
	# Installed but config missing
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

# Check if ldap directory permissions are correct
$p = &check_ldap_permissions();
if (!$p) {
	print "<center>\n";
	print &ui_form_start("perms.cgi");
	print &text('index_permsdesc', "<tt>$config{'data_dir'}</tt>",
				       "<tt>$config{'ldap_user'}</tt>"),"<p>\n";
	print &ui_form_end([ [ undef, $text{'index_perms'} ] ]);
	print "</center>\n";
	print &ui_hr();
	}

# Check if need to init new install, by creating the root DN
$ldap = &connect_ldap_db();
if ($p && ref($ldap) && $access{'browser'}) {
	$conf = &get_config();
	$base = &find_value("suffix", $conf);
	$rv = $ldap->search(base => $base,
			    filter => '(objectClass=*)',
			    scope => 'base');
	if ($rv->code) {
		# Not found .. offer to init
		print "<center>\n";
		print &ui_form_start("create.cgi");
		print &ui_hidden('mode', 1);
		print &ui_hidden('dn', $base);
		print &text('index_setupdesc', "<tt>$base</tt>"),"<p>\n";
		print &ui_form_end([ [ undef, $text{'index_setup'} ] ]);
		print "</center>\n";
		print &ui_hr();
		}
	}

# Work out icons
if ($local) {
	# All local server icons
	@pages = ( &get_config_type() == 1 ? "slapd" : "ldif",
		   "schema", "acl", "browser", "create" );
	}
else {
	# Just browser and DN creator
	@pages = ( "browser", "create" );
	}
@pages = grep { $access{$_} } @pages;
@links = map { "edit_".$_.".cgi" } @pages;
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/$_.gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 5);

if ($local == 1) {
	# Show stop/restart buttons
	print &ui_hr();
	print &ui_buttons_start();
	if (&is_ldap_server_running()) {
		if ($access{'apply'}) {
			print &ui_buttons_row("apply.cgi", $text{'index_apply'},
					      $text{'index_applydesc'});
			}
		if ($access{'start'}) {
			print &ui_buttons_row("stop.cgi", $text{'index_stop'},
					      $text{'index_stopdesc'});
			}
		}
	else {
		if ($access{'start'}) {
			print &ui_buttons_row("start.cgi", $text{'index_start'},
					      $text{'index_startdesc'});
			}
		}

	# Start at boot button
	if (&foreign_check("init") && $access{'start'}) {
		&foreign_require("init", "init-lib.pl");
		$iname = $config{'init_name'} || $module_name;
		$st = &init::action_status($iname);
		print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
				      $text{'index_bootdesc'},
				      undef,
				      &ui_yesno_radio("boot",$st == 2 ? 1 : 0));
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});
