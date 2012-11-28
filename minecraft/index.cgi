#!/usr/local/bin/perl
# Show icons for config editing, whitelist and ops

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

my $err = &check_minecraft_server();
if ($err) {
	&ui_print_endpage(&text('index_cerr', $err, "../config.cgi?$module_name"));
	}

my @links = ( "edit_conf.cgi", "edit_users.cgi",
	      "view_logs.cgi", "edit_manual.gif" );
my @titles = ( $text{'conf_title'}, $text{'users_title'},
	       $text{'logs_title'}, $text{'manual_title'} );
my @icons = ( "images/conf.gif", "images/users.gif",
	      "images/logs.gif", "images/manual.gif" );
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
print &ui_buttons_start();

# Show start/stop/restart buttons
my $pid = &is_minecraft_server_running();
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

&ui_print_footer("/", $text{'index_return'});

