#!/usr/local/bin/perl
# Save server properties

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();
&lock_file(&get_minecraft_config_file());
my $conf = &get_minecraft_config();
&error_setup($text{'conf_err'});

# Validate and store inputs, starting with seed
if ($in{'seed_def'}) {
	&save_directive("level-seed", "", $conf);
	}
else {
	$in{'seed'} =~ /^\S+$/ || &error($text{'conf_seed'});
	&save_directive("level-seed", $in{'seed'}, $conf);
	}

# New world type
&save_directive("level-type", $in{'type'}, $conf);

# Generate structures?
&save_directive("generate-structures", $in{'structs'} ? 'true' : 'false', $conf);

# Allow nether?
&save_directive("allow-nether", $in{'nether'} ? 'true' : 'false', $conf);

# Startup difficulty
&save_directive("difficulty", $in{'diff'}, $conf);

# Default game mode
&save_directive("gamemode", $in{'gamemode'}, $conf);

# Allow flight
&save_directive("allow-flight", $in{'flight'} ? 'true' : 'false', $conf);

# Hardcore mode
&save_directive("hardcore", $in{'hardcore'} ? 'true' : 'false', $conf);

# Online mode
&save_directive("online-mode", $in{'online'} ? 'true' : 'false', $conf);

# Allow player vs player
&save_directive("pvp", $in{'pvp'} ? 'true' : 'false', $conf);

# Max players
$in{'players'} =~ /^[1-9]\d*$/ || &error($text{'conf_eplayers'});
&save_directive("max-players", $in{'players'}, $conf);

# Message of the day
$in{'motd_def'} || $in{'motd'} =~ /\S/ || &error($text{'conf_emotd'});
&save_directive("motd", $in{'motd_def'} ? undef : $in{'motd'}, $conf);

# Max build height
$in{'build'} =~ /^[1-9]\d*$/ || &error($text{'conf_ebuild'});
&save_directive("max-build-height", $in{'build'}, $conf);

# Spawn various creatures
foreach my $s ("animals", "monsters", "npcs") {
	&save_directive("spawn-$s", $in{$s} ? "true" : "false", $conf);
	}

# Spawn protection range
$in{'protect_def'} || $in{'protect'} =~ /^\d+$/ ||
	&error($text{'conf_eprotect'});
&save_directive("spawn-protection", $in{'protect_def'} ? undef : $in{'protect'},
		$conf);

# IP address
$in{'ip_def'} || &check_ipaddress($in{'ip'}) ||
	&error($text{'conf_eip'});
&save_directive("server-ip", $in{'ip_def'} ? undef : $in{'ip'}, $conf);

# TCP port
$in{'port_def'} || $in{'port'} =~ /^\d+$/ ||
	&error($text{'conf_eport'});
&save_directive("server-port", $in{'port_def'} ? undef : $in{'port'}, $conf);

# Query port
&save_directive("enable-query", $in{'query'} ? 'true' : 'false', $conf);

# Remote console port
&save_directive("enable-rcon", $in{'rcon'} ? 'true' : 'false', $conf);

# Write out the file
&flush_file_lines(&get_minecraft_config_file());
&unlock_file(&get_minecraft_config_file());
&webmin_log("conf");
&redirect("");
