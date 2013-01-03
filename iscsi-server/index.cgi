#!/usr/local/bin/perl
# Display icons for iSCSI extents, devices and targets

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("netbsd-iscsi", "man", "doc", "google"));

my $err = &check_config();
if ($err) {
	&ui_print_endpage(
		$err." ".&text('index_clink', "../config.cgi?$module_name"));
	}

my @links = ( "list_extents.cgi", "list_devices.cgi",
	      "list_targets.cgi", "edit_opts.cgi",
	      "list_users.cgi", "edit_manual.cgi" );
my @titles = ( $text{'extents_title'}, $text{'devices_title'},
	       $text{'targets_title'}, $text{'opts_title'},
	       $text{'users_title'}, $text{'manual_title'} );
my @icons = ( "images/extents.gif", "images/devices.gif",
	      "images/targets.gif", "images/opts.gif",
	      "images/users.gif", "images/manual.gif" );
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
print &ui_buttons_start();

# Show start/stop/restart buttons
my $pid = &is_iscsi_server_running();
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

# Show start at boot button
&foreign_require("init");
my $starting = &init::action_status($config{'init_name'});
print &ui_buttons_row("atboot.cgi",
		      $text{'index_atboot'},
		      $text{'index_atbootdesc'},
		      undef,
		      &ui_radio("boot", $starting == 2 ? 1 : 0,
				[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
