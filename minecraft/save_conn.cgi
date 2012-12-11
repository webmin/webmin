#!/usr/local/bin/perl
# Perform some action on a player

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();
&error_setup($text{'conn_err'});

my $msg;
if ($in{'msg'}) {
	# Send a message
	$in{'text'} =~ /\S/ || &error($text{'conn_etext'});
	&send_server_command("/say $in{'name'} $in{'text'}");
	$msg = $text{'conn_msgdone'};
	}
elsif ($in{'kill'}) {
	# Kill this player
	&send_server_command("/kill $in{'name'}");
	$msg = $text{'conn_killdone'};
	}
elsif ($in{'give'}) {
	# Give an item
	$in{'id'} =~ /^\d+$/ || &error($text{'conn_eid'});
	$in{'count'} =~ /^\d+$/ || &error($text{'conn_ecount'});
	my ($i) = grep { $_->{'id'} eq $in{'id'} }
		       &list_minecraft_items();
	my $out = &execute_minecraft_command(
		"/give $in{'name'} $in{'id'} $in{'count'}");
	$out =~ /Given.*\Q$in{'name'}\E/ ||
		&error(&html_escape($out));
	$msg = &text('conn_givedone', $i ? $i->{'name'} : $in{'id'},
				      $in{'count'});
	}
else {
	# No button clicked!
	&error($text{'conn_ebutton'});
	}
&redirect("view_conn.cgi?name=".&urlize($in{'name'})."&msg=".
	  &urlize($msg));


