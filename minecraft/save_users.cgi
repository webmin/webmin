#!/usr/local/bin/perl
# Update whitelisted or operator users

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();
my $conf = &get_minecraft_config();
&error_setup($text{'users_err'});

if ($in{'mode'} eq 'white') {
	# Update whitelist, and maybe apply it
	&lock_file(&get_minecraft_config_file());
	&lock_file(&get_whitelist_file());
	my @users = split(/\r?\n/, $in{'white'});
	&save_whitelist_users(\@users);
	&save_directive("white-list", $in{'enabled'} ? 'true' : 'false', $conf);
	&flush_file_lines(&get_minecraft_config_file());
	&unlock_file(&get_whitelist_file());
	&unlock_file(&get_minecraft_config_file());

	if ($in{'apply'}) {
		&send_server_command("/whitelist reload");
		&send_server_command("/whitelist ".
			($in{'enabled'} ? "on" : "off"));
		}

	&webmin_log('white');
	}
elsif ($in{'mode'} eq 'op') {
	# Update operator list
	&lock_file(&get_op_file());
	my @users = split(/\r?\n/, $in{'op'});
	&save_op_users(\@users);
	&unlock_file(&get_op_file());
	&webmin_log('op');
	}
else {
	&error($text{'users_emode'});
	}
&redirect("");

