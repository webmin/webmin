#!/usr/local/bin/perl
# Execute some world-level command

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();
&error_setup($text{'cmds_err'});

my $msg;
if ($in{'gamemode'}) {
	# Change game mode
	my $out = &execute_minecraft_command(
                "/defaultgamemode $in{'defmode'}");
	$out =~ /The\s+world's\s+default\s+game\s+mode/ ||
                &error(&html_escape($out));
	$msg = &text('cmds_gamemodedone', $in{'defmode'});
	}
elsif ($in{'difficulty'}) {
	# Change game mode
	&send_server_command("/difficulty $in{'diff'}");
	$msg = $text{'cmds_difficultydone'};
	}
elsif ($in{'time'}) {
	# Change game time
	my $mode;
	if ($in{'time_mode'} == 0) {
		$mode = 'set day';
		}
	elsif ($in{'time_mode'} == 1) {
		$mode = 'set night';
		}
	elsif ($in{'time_mode'} == 2) {
		$in{'timeset'} =~ /^\d+$/ &&
		  $in{'timeset'} >= 0 && $in{'timeset'} <= 24000 ||
		    &error($text{'cmds_etimeset'});
		$mode = 'set '.$in{'timeset'};
		}
	elsif ($in{'time_mode'} == 3) {
		$in{'timeadd'} =~ /^\d+$/ &&
		  $in{'timeadd'} >= 0 && $in{'timeadd'} <= 24000 ||
		    &error($text{'cmds_etimeadd'});
		$mode = 'add '.$in{'timeadd'};
		}
	my $out = &execute_minecraft_command(
                "/time $mode");
	$out =~ /Set\s+the\s+time/ || $out =~ /Added.*to\s+the\s+time/ ||
                &error(&html_escape($out));
	$msg = &text('cmds_timedone');
	}
elsif ($in{'downfall'}) {
	# Start rain
	my $out = &execute_minecraft_command(
                "/toggledownfall");
	$out =~ /Toggled\s+downfall/ ||
                &error(&html_escape($out));
	$msg = &text('cmds_downfalldone');
	}
elsif ($in{'weather'}) {
	# Change weather
	$in{'secs'} =~ /^[1-9][0-9]*$/ ||
		&error($text{'cmds_esecs'});
	my $out = &execute_minecraft_command(
                "/weather $in{'wtype'} $in{'secs'}");
	$out =~ /Changing\s+to/ ||
                &error(&html_escape($out));
	$msg = &text('cmds_weatherdone', $in{'wtype'}, $in{'secs'});
	}
elsif ($in{'say'}) {
	# Broadcast message
	$in{'text'} =~ /\S/ || &error($text{'conn_etext'});
	&send_server_command("/say $in{'text'}");
	$msg = $text{'cmds_msgdone'};
	}
else {
	&error($text{'conn_ebutton'});
	}

&redirect("edit_cmds.cgi?msg=".&urlize($msg));
