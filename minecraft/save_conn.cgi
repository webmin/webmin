#!/usr/local/bin/perl
# Perform some action on a player

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();
&error_setup($text{'conn_err'});
my $uuid = &uuid_to_username($in{'name'});

my $msg;
if ($in{'msg'}) {
	# Send a message
	$in{'text'} =~ /\S/ || &error($text{'conn_etext'});
	&send_server_command("/msg $in{'name'} $in{'text'}");
	$msg = $text{'conn_msgdone'};
	}
elsif ($in{'kill'}) {
	# Kill this player
	&send_server_command("/kill $in{'name'}");
	$msg = $text{'conn_killdone'};
	}
elsif ($in{'kick'}) {
	# Disconnect this player
	&send_server_command("/kick $in{'name'}");
	$msg = $text{'conn_kickdone'};
	}
elsif ($in{'give'}) {
	# Give an item
	$in{'id'} =~ /^\S+$/ || &error($text{'conn_eid'});
	my $data = "";
	if ($in{'id'} =~ s/:(\d+)$//) {
		$data = $1;
		}
	$in{'count'} =~ /^\d+$/ || &error($text{'conn_ecount'});
	my ($i) = grep { $_->{'id'} eq $in{'id'} }
		       &list_minecraft_items();
	my $out = &execute_minecraft_command(
		"/give $in{'name'} $in{'id'} $in{'count'} $data");
	$out =~ /Given.*\Q$in{'name'}\E/ ||
		&error(&html_escape($out));
	$msg = &text('conn_givedone', $i ? $i->{'name'} : $in{'id'},
				      $in{'count'});
	}
elsif ($in{'xp'}) {
	# Grant XP
	$in{'xpadd'} =~ /^\d+$/ || &error($text{'conn_exp'});
	my $xp;
	if ($in{'xpmode'} == 0) {
		$xp = $in{'xpadd'};
		}
	else {
		$xp = &level_to_orbs($in{'xpadd'});
		$xp || &error($text{'conn_explevel'});
		}
	my $out = &execute_minecraft_command(
		"/xp $xp $in{'name'}");
	$out =~ /Given.*experience.*\Q$in{'name'}\E/ ||
		&error(&html_escape($out));
	$msg = &text('conn_xpdone', $xp);
	}
elsif ($in{'spawn'}) {
	# Change spawn point
	$in{'spawnx'} =~ /^\-?([0-9]+)$/ || &error($text{'conn_ex'});
	$in{'spawny'} =~ /^\-?([0-9]+)$/ || &error($text{'conn_ey'});
	$in{'spawnz'} =~ /^\-?([0-9]+)$/ || &error($text{'conn_ez'});
	my $out = &execute_minecraft_command(
		"/spawnpoint $in{'name'} $in{'spawnx'} $in{'spawny'} $in{'spawnz'}");
	$out =~ /Set\s+\Q$in{'name'}\E/ ||
		&error(&html_escape($out));
	$msg = &text('conn_spawndone', $in{'spawnx'}, $in{'spawny'}, $in{'spawnz'});
	}
elsif ($in{'tp'}) {
	$in{'tpx'} =~ /^\~?\-?([0-9]+)$/ || &error($text{'conn_ex'});
	$in{'tpy'} =~ /^\~?\-?([0-9]+)$/ || &error($text{'conn_ey'});
	$in{'tpz'} =~ /^\~?\-?([0-9]+)$/ || &error($text{'conn_ez'});
	my $out = &execute_minecraft_command(
		"/tp $in{'name'} $in{'tpx'} $in{'tpy'} $in{'tpz'}");
	$out =~ /Teleported\s+\Q$in{'name'}\E/ ||
		&error(&html_escape($out));
	$msg = &text('conn_tpdone', $in{'tpx'}, $in{'tpy'}, $in{'tpz'});
	}
elsif ($in{'tpp'}) {
	my $out = &execute_minecraft_command(
		"/tp $in{'name'} $in{'player'}");
	$out =~ /Teleported\s+\Q$in{'name'}\E/ ||
		&error(&html_escape($out));
	$msg = &text('conn_tppdone', $in{'player'});
	}
elsif ($in{'ban'}) {
	my $out = &execute_minecraft_command(
                "/ban $in{'name'} $in{'reason'}");
	$out =~ /Banned\s+player\s+\Q$in{'name'}\E/ ||
                &error(&html_escape($out));
	$msg = &text('conn_bandone', $in{'name'});
	}
elsif ($in{'pardon'}) {
	my $out = &execute_minecraft_command(
                "/pardon $in{'name'}");
	$out =~ /Unbanned\s+player\s+\Q$in{'name'}\E/ ||
                &error(&html_escape($out));
	$msg = &text('conn_pardondone', $in{'name'});
	}
elsif ($in{'op'}) {
	my $out = &execute_minecraft_command(
                "/op $in{'name'}");
	$out =~ /Opped\s+\Q$in{'name'}\E/ ||
                &error(&html_escape($out));
	$msg = &text('conn_opdone');
	}
elsif ($in{'deop'}) {
	my $out = &execute_minecraft_command(
                "/deop $in{'name'}");
	$out =~ /De-opped\s+\Q$in{'name'}\E/ ||
                &error(&html_escape($out));
	$msg = &text('conn_deopdone');
	}
else {
	# No button clicked!
	&error($text{'conn_ebutton'});
	}
&redirect("view_conn.cgi?name=".&urlize($in{'name'})."&msg=".
	  &urlize($msg));


