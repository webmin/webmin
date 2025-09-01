#!/usr/local/bin/perl
# Show the dovecot config menu

require './dovecot-lib.pl';
$ver = &get_dovecot_version();
&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1, 0,
		 &help_search_link("dovecot", "man", "doc", "google"),
		 undef, undef,
		 $ver ? &text('index_version', $ver) : undef);

# Make sure dovecot is installed
if (!&has_command($config{'dovecot'})) {
	print &ui_config_link('index_ecmd',
		        [ "<tt>$config{'dovecot'}</tt>", undef ]),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"dovecot", $text{'index_dovecot'},
			"../$module_name/", $module_info{'desc'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check for config file
if (!&get_config_file()) {
	print &ui_config_link('index_econf',
		[ "<tt>$config{'dovecot_config'}</tt>", undef ]),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Show icons for option categories
@pages = ( "net", "login", "mail", "ssl", "manual" );
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/".$_.".gif" } @pages;
@links = map { "edit_".$_.".cgi" } @pages;
&icons_table(\@links, \@titles, \@icons, scalar(@titles));

# Show start/stop and atboot buttons
print &ui_hr();
print &ui_buttons_start();

if (&is_dovecot_running()) {
	print &ui_buttons_row("apply.cgi", $text{'index_apply'},
			      $text{'index_applydesc'});
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopdesc'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'});
	}

if ($config{'init_script'}) {
	&foreign_require("init");
	$atboot = &init::action_status($config{'init_script'});
	print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
			      $text{'index_bootdesc'}, undef,
			      &ui_radio("boot", $atboot == 2 ? 1 : 0,
					[ [ 1, $text{'yes'} ],
					  [ 0, $text{'no'} ] ]));
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

