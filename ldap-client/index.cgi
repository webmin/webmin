#!/usr/local/bin/perl
# Show icons for various categories of options

require './ldap-client-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", "intro", 1, 1);

# Make sure the config file exists
if (!-r $config{'auth_ldap'}) {
	&ui_print_endpage(
		&ui_config_link('index_econf',
			[ "<tt>$config{'auth_ldap'}</tt>", undef ]));
	}

# Show icons for option categories
@pages = ( "server", "base", "pam", "switch", "browser" );
@links = map { $_ eq "browser" ? "browser.cgi" :
	       $_ eq "switch" ?  "list_switches.cgi" :
				 "edit_".$_.".cgi" } @pages;
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/".$_.".gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 5);

# Validate button
print "<hr>\n";
print &ui_buttons_start();
print &ui_buttons_row("check.cgi", $text{'index_check'},
		      $text{'index_checkdesc'});
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

