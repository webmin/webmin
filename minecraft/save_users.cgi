#!/usr/local/bin/perl
# Update whitelisted or operator users

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
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
		&send_server_command("whitelist reload");
		&send_server_command("whitelist ".
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
elsif ($in{'mode'} eq 'ip') {
	# Update banned IP list
	my @newips = split(/\s+/, $in{'ip'});
	foreach my $ip (@newips) {
		&check_ipaddress(@newips) ||
			&error(&text('users_eip', $ip));
		}
	@newips = &unique(@newips);
	my %oldips = map { $_, 1 } &list_banned_ips();
	foreach my $ip (@newips) {
		if (!$oldips{$ip}) {
			&send_server_command("ban-ip $ip");
			}
		delete($oldips{$ip});
		}
	foreach my $ip (keys %oldips) {
		&send_server_command("pardon-ip $ip");
		}
	&webmin_log('ip');
	}
else {
	&error($text{'users_emode'});
	}
&redirect("");

