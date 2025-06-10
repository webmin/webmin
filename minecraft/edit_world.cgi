#!/usr/local/bin/perl
# Show a form to edit or create a world

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();
my @worlds = &list_worlds();
my $conf = &get_minecraft_config();
my $def = &find_value("level-name", $conf);

# Get world, show title
my $world;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'world_create'}, "");
	$world = { };
	}
else {
	&ui_print_header(undef, $text{'world_edit'}, "");
	($world) = grep { $_->{'name'} eq $in{'name'} } @worlds;
	$world || &error($text{'world_egone'});
	}

print &ui_form_start("save_world.cgi", "form-data");
print &ui_table_start($text{'world_header'}, undef, 2);
print &ui_hidden("new", $in{'new'});

if ($in{'new'}) {
	# World name
	print &ui_table_row($text{'world_name'},
		&ui_textbox("name", undef, 20));

	# Source of data
	my @opts = ( [ 0, $text{'world_src0'} ] );
	if (@worlds) {
		push(@opts, [ 1, $text{'world_src1'},
			      &ui_select("world", undef,
				[ map { $_->{'name'} } @worlds ]) ]);
		}
	push(@opts, [ 2, $text{'world_src2'},
		      &ui_upload("upload") ]);
	push(@opts, [ 3, $text{'world_src3'},
		      &ui_filebox("file", undef, 40) ]);
	print &ui_table_row($text{'world_src'},
		&ui_radio_table("src", 0, \@opts));
	}
else {
	# World name (non-editable)
	print &ui_table_row($text{'world_name'},
		"<tt>$world->{'name'}</tt>");
	print &ui_hidden("name", $in{'name'});

	# Current state
	print &ui_table_row($text{'world_state'},
		!&is_minecraft_server_running() ?
			$text{'world_state0'} :
		$def eq $world->{'name'} ? 
			$text{'world_state1'} :
			$text{'world_state2'});

	# Size
	print &ui_table_row($text{'worlds_size'},
		&nice_size($world->{'size'}));

	# Seed, if active
	if (&is_minecraft_server_running() && $def eq $world->{'name'}) {
		my $out = &execute_minecraft_command("/seed");
		if ($out =~ /Seed:\s+(\S+)/) {
			print &ui_table_row($text{'worlds_seed'}, $1);
			}
		}

	# All players
	if (@{$world->{'players'}}) {
		my @grid = map { "<a href='view_conn.cgi?name=".&urlize($_).
				 "'>".&html_escape($_)."</a>&nbsp;&nbsp;" }
			       @{$world->{'players'}};
		print &ui_table_row($text{'world_players'},
			&ui_grid_table(\@grid, 4, 100));
		}
	}

print &ui_table_end();
print &ui_form_end(
	$in{'new'} ? [ [ undef, $text{'create'} ] ]
		   : [ [ 'delete', $text{'world_delete'} ],
		       [ 'download', $text{'world_download'} ] ],
	);

&ui_print_footer("list_worlds.cgi", $text{'worlds_return'});
