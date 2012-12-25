#!/usr/local/bin/perl
# Execute some world-level command

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();
&error_setup($text{'cmds_err'});

my $msg;
if ($in{'gamemode'}) {
	# Change game mode
	}
elsif ($in{'difficulty'}) {
	# Change game mode
	}
elsif ($in{'downfall'}) {
	# Start rain
	my $out = &execute_minecraft_command(
                "/toggledownfall");
	$out =~ /Toggled\s+downfall/ ||
                &error(&html_escape($out));
	$msg = &text('cmds_downfalldone');
	}
else {
	&error($text{'conn_ebutton'});
	}

&redirect("edit_cmds.cgi?msg=".&urlize($msg));
