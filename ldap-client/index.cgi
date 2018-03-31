#!/usr/local/bin/perl
# Show icons for various categories of options

require './ldap-client-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", "intro", 1, 1);

# Make sure the config file exists
my $cfile = &get_ldap_config_file();
if (!$cfile || !-r $cfile) {
	&foreign_require("software");
	$lnk = &software::missing_install_link("ldap", $text{'index_ldapmod'},
                        "../$module_name/", $module_info{'desc'});
	&ui_print_endpage(
		&ui_config_link('index_econf',
			[ "<tt>".$cfile."</tt>", undef ]).
		($lnk ? "<p>\n".$lnk : ""));
	}

# Check for separate config files for PAM and NSS
if ($config{'pam_ldap'} && -r $config{'pam_ldap'} && !$config{'nofixpam'} &&
    !&same_file($config{'pam_ldap'}, &get_ldap_config_file())) {
	print "<center>\n";
	print &ui_form_start("fixpam.cgi");
	print &text('index_fixpam',
		"<tt>".&html_escape(&get_ldap_config_file())."</tt>",
		"<tt>".&html_escape($config{'pam_ldap'})."</tt>"),"<p>\n";
	print &ui_form_end([ [ undef, $text{'index_fix'} ],
			     [ "ignore", $text{'index_ignore'} ] ]);
	print "</center>\n";
	}

# Show icons for option categories
@pages = ( "server", "base", "pam", "switch", "browser" );
@links = map { $_ eq "browser" ? "browser.cgi" :
	       $_ eq "switch" ?  "list_switches.cgi" :
				 "edit_".$_.".cgi" } @pages;
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/".$_.".gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 5);

print &ui_hr();
print &ui_buttons_start();

# Validate button
print &ui_buttons_row("check.cgi", $text{'index_check'},
		      $text{'index_checkdesc'});

# LDAP server daemon
&foreign_require("init");
if ($config{'init_name'} &&
    ($st = &init::action_status($config{'init_name'}))) {
	# Start or stop
	if (&init::status_action($config{'init_name'}) == 1) {
		print &ui_buttons_row("restart.cgi", $text{'index_restart'},
				      $text{'index_restartdesc'});
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
				      $text{'index_stopdesc'});
		}
	else {
		print &ui_buttons_row("start.cgi", $text{'index_start'},
				      $text{'index_startdesc'});
		}

	# Start at boot
	print &ui_buttons_row("atboot.cgi",
			      $text{'index_atboot'},
			      $text{'index_atbootdesc'},
			      undef,
			      &ui_radio("boot", $st == 2 ? 1 : 0,
				[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

