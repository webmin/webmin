#!/usr/local/bin/perl
# Show icons for jails, filter, etc

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config, $module_name, $module_root_directory);

my $ver = &get_fail2ban_version();
&ui_print_header($ver ? &text('index_ver', $ver) : undef,
		 $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("fail2ban", "google", "man"));

# Check if installed
my $err = &check_fail2ban();
if ($err) {
	print &text('index_echeck', $err, "../config.cgi?$module_name"),"<p>\n";

	&foreign_require("software");
	my $lnk = &software::missing_install_link("fail2ban",
		$text{'index_fail2ban'}, "../$module_name/",
		$text{'index_header'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index_return'});
	return;
	}

# Show category icons
my @links = ( "list_filters.cgi", "list_actions.cgi",
	      "list_jails.cgi", "list_status.cgi",
	      "edit_config.cgi", "edit_manual.cgi", );
my @titles = ( $text{'filters_title'}, $text{'actions_title'},
	       $text{'jails_title'}, $text{'status_title'},
	       $text{'config_title'}, $text{'manual_title'}, );
my @icons = ( "images/filters.gif", "images/actions.gif",
	      "images/jails.gif", "images/status.gif",
	      "images/config.gif", "images/manual.gif", );
&icons_table(\@links, \@titles, \@icons, 5);

# Show start / stop buttons
print &ui_hr();
print &ui_buttons_start();

my $pid = &is_fail2ban_running();
if ($pid) {
	print &ui_buttons_row("restart.cgi", $text{'index_restart'},
			      $text{'index_restartdesc'});
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopdesc'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'});
	}

# Enable at boot
if ($config{'init_script'}) {
	&foreign_require("init");
	my @inits = split(/\s+/, $config{'init_script'});
	my $st = &init::action_status($inits[0]);
	print &ui_buttons_row(
		"atboot.cgi",
		$text{'index_atboot'},
		$text{'index_atbootdesc'},
		undef,
		&ui_radio("boot", $st == 2 ? 1 : 0,
			  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
