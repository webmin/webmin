#!/usr/local/bin/perl
# Show icons for users, profiles and so on

require './rbac-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1, 0,
		 &help_search_link("rbac", "man"));

# Make sure RBAC is installed
$missing = &missing_rbac_config_file();
if ($missing) {
	&ui_print_endpage(
		&ui_config_link('index_euser',
			[ "<tt>$missing</tt>", undef ]));
	}

# Show icons
@allpages = ( "users", "auths", "profs", "execs", "policy",
	      "projects", "prctl" );
@pages = grep { $_ eq "users" ? $access{'users'} || $access{'roles'}
			      : $access{$_} } @allpages;
@links = map { "list_${_}.cgi" } @pages;
@titles = map { $text{"${_}_title"} } @pages;
@icons = map { "images/${_}.gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 4);

&ui_print_footer("/", $text{"index"});
