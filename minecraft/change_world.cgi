#!/usr/local/bin/perl
# Update the default world

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'worlds_err'});
$in{'d'} || &error($text{'worlds_esel'});

my $conf = &get_minecraft_config();
my $def = &find_value("level-name", $conf);
if ($def ne $in{'d'}) {
	&lock_file(&get_minecraft_config_file());
	&save_directive("level-name", $in{'d'}, $conf);
	&flush_file_lines(&get_minecraft_config_file());
	&unlock_file(&get_minecraft_config_file());
	if ($in{'apply'} && &is_minecraft_server_running()) {
		&stop_minecraft_server();
		my $err = &start_minecraft_server();
		&error($err) if ($err);
		}
	}
&redirect("list_worlds.cgi");
