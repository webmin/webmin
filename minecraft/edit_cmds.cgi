#!/usr/local/bin/perl
# Show a form for world-level commands

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text);
&ReadParse();

&ui_print_header(undef, $text{'cmds_title'}, "");

# Show message from action
if ($in{'msg'}) {
	print "<b><font color=green>$in{'msg'}</font></b><p>\n";
	}

print &ui_form_start("save_cmds.cgi", "post");
print &ui_table_start($text{'cmds_header'}, undef, 2);

# Change default game mode
print &ui_table_row($text{'cmds_gamemode'},
	&ui_select("defmode", "survival",
		   [ [ 'survival', $text{'cmds_survival'} ],
		     [ 'creative', $text{'cmds_creative'} ],
		     [ 'adventure', $text{'cmds_adventure'} ] ]).' '.
	&ui_submit($text{'cmds_gamemodeb'}, 'gamemode'));

# Change difficulty level
print &ui_table_row($text{'cmds_difficulty'},
	&ui_select("diff", 2,
		   [ [ 'peaceful', $text{'cmds_peaceful'} ],
		     [ 'easy', $text{'cmds_easy'} ],
		     [ 'normal', $text{'cmds_normal'} ],
		     [ 'hard', $text{'cmds_hard'} ] ])." ".
	&ui_submit($text{'cmds_difficultyb'}, 'difficulty'));

# Change time
print &ui_table_row($text{'cmds_time'},
	&ui_radio_table("time_mode", 0,
			[ [ 0, $text{'cmds_day'} ],
			  [ 1, $text{'cmds_night'} ],
			  [ 2, $text{'cmds_set'},
			    &ui_textbox("timeset", 0, 6)." (0-24000)" ],
			  [ 3, $text{'cmds_add'},
			    &ui_textbox("timeadd", 0, 6)." (0-24000)" ] ])." ".
	&ui_submit($text{'cmds_timeb'}, 'time'));

# Start rain / snow
print &ui_table_row($text{'cmds_downfall'},
	&ui_submit($text{'cmds_downfallb'}, 'downfall'));

# Change weather
print &ui_table_row($text{'cmds_weather'},
	&ui_select("wtype", "clear",
		   [ [ 'clear', $text{'cmds_clear'} ],
		     [ 'rain', $text{'cmds_rain'} ],
		     [ 'thunder', $text{'cmds_thunder'} ] ])." ".
	$text{'cmds_for'}." ".
	&ui_textbox("secs", 5, 5)." ".
	&ui_submit($text{'cmds_weatherb'}, 'weather'));

# Broadcast message
print &ui_table_row($text{'cmds_say'},
	&ui_textbox("text", undef, 40)." ".
	&ui_submit($text{'cmds_sayb'}, 'say'));

print &ui_table_end();
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

