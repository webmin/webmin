#!/usr/local/bin/perl
# Show icons for config editing, whitelist and ops

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("minecraft", "google"));

my $err = &check_minecraft_server();
if ($err && &is_minecraft_port_in_use()) {
	# Not found, but server appears to be running
	&ui_print_endpage(&text('index_cerr', $err,
			  "../config.cgi?$module_name"));
	}
elsif ($err) {
	# Not found, and not running. Offer to setup.
	print &text('index_cerr2', "../config.cgi?$module_name"),"<p>\n";

	if (&has_command($config{'java_cmd'})) {
		print &ui_form_start("download.cgi");
		print &ui_hidden("new", 1);
		print $text{'index_offer'},"<p>\n";
		print &ui_table_start(undef, undef, 2);
		print &ui_table_row($text{'index_dir'},
			&ui_textbox("dir", $config{'minecraft_dir'}, 40));
		print &ui_table_row($text{'index_user'},
			&ui_user_textbox("user", "nobody"));
		print &ui_table_end();
		print &ui_form_end([ [ undef, $text{'index_install'} ] ]);
		}
	else {
		print &text('index_nojava', $config{'java_cmd'}),"<p>\n";
		}
	return;
	}

# Check if new version is out, if we haven't checked in the last 6 hours
if (time() - $config{'last_check'} > 6*60*60) {
	my $sz = &check_server_download_size();
	$config{'last_check'} = time();
	$config{'last_size'} = $sz;
	&save_module_config();
	}
if ($config{'last_size'}) {
	my $jar = $config{'minecraft_jar'} ||
		  $config{'minecraft_dir'}."/"."minecraft_server.jar";
	my @st = stat($jar);
	if (@st && $st[7] != $config{'last_size'}) {
		print "<table width=100%><tr bgcolor=#ff8888>".
		      "<td align=center><br>";
		print &ui_form_start("download.cgi");
		print "<b>$text{'index_upgradedesc'}</b>\n";
		print &ui_form_end([ [ undef, $text{'index_upgrade'} ] ]);
		print "</td></tr></table>\n";
		}
	}

my @links = ( "edit_conf.cgi", "edit_users.cgi",
	      "view_logs.cgi", "list_conns.cgi",
	      "list_worlds.cgi", "edit_cmds.cgi",
	      "console.cgi", "edit_backup.cgi",
	      "edit_manual.cgi" );
my @titles = ( $text{'conf_title'}, $text{'users_title'},
	       $text{'logs_title'}, $text{'conns_title'},
	       $text{'worlds_title'}, $text{'cmds_title'},
	       $text{'console_title'}, $text{'backup_title'},
	       $text{'manual_title'} );
my @icons = ( "images/conf.gif", "images/users.gif",
	      "images/logs.gif", "images/conns.gif",
	      "images/worlds.gif", "images/cmds.gif",
	      "images/console.gif", "images/backup.gif",
	      "images/manual.gif" );
&icons_table(\@links, \@titles, \@icons, 5);

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

# Show download button
print &ui_buttons_row("download.cgi", $text{'index_download'},
		      $text{'index_downloaddesc'});

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

