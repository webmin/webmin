#!/usr/local/bin/perl
# Show a form for editing server config variables

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
my $conf = &get_minecraft_config();

&ui_print_header(undef, $text{'conf_title'}, "");

print $text{'conf_desc'},"<p>\n";

print &ui_form_start("save_conf.cgi", "post");
print &ui_table_start($text{'conf_header'}, undef, 4);

#### World-related options

# Seed for new worlds
my $seed = &find_value("level-seed", $conf);
print &ui_table_row($text{'conf_seed'},
	&ui_opt_textbox("seed", $seed, 20, $text{'conf_random'}), 3);

# Type for new worlds
my $type = &find_value("level-type", $conf) || "DEFAULT";
print &ui_table_row($text{'conf_type'},
	&ui_select("type", uc($type),
		[ [ "DEFAULT", $text{'conf_type_default'} ],
		  [ "FLAT", $text{'conf_type_flat'} ],
		  [ "AMPLIFIED", $text{'conf_type_amplified'} ],
		  [ "LARGEBIOMES", $text{'conf_type_largebiomes'} ] ], 1, 0,1));

# Generate structures in new worlds
my $structs = &find_value("generate-structures", $conf) || "true";
print &ui_table_row($text{'conf_structs'},
	&ui_yesno_radio("structs", lc($structs) eq "true"));

# Allow nether
my $nether = &find_value("allow-nether", $conf) || "true";
print &ui_table_row($text{'conf_nether'},
	&ui_yesno_radio("nether", lc($nether) eq "true"));

# Allow command block
my $command = &find_value("enable-command-block", $conf) || "false";
print &ui_table_row($text{'conf_command'},
	&ui_yesno_radio("command", lc($command) eq "true"));

print &ui_table_hr();

#### Game-related options

# Startup difficulty
my $diff = &find_value("difficulty", $conf);
$diff = 1 if (!defined($diff));
print &ui_table_row($text{'conf_difficulty'},
	&ui_select("diff", $diff,
		   [ [ 'peaceful', $text{'cmds_peaceful'} ],
		     [ 'easy', $text{'cmds_easy'} ],
		     [ 'normal', $text{'cmds_normal'} ],
		     [ 'hard', $text{'cmds_hard'} ] ]));

# Default game mode
my $gamemode = &find_value("gamemode", $conf);
$gamemode = 0 if (!defined($gamemode));
print &ui_table_row($text{'conf_gamemode'},
	&ui_select("gamemode", $gamemode,
                   [ [ 0, $text{'cmds_survival'} ],
                     [ 1, $text{'cmds_creative'} ],
                     [ 2, $text{'cmds_adventure'} ] ]));

# Allow flight
my $flight = &find_value("allow-flight", $conf) || "false";
print &ui_table_row($text{'conf_flight'},
	&ui_yesno_radio("flight", lc($flight) eq "true"));

# Hardcore mode
my $hardcore = &find_value("hardcore", $conf) || "false";
print &ui_table_row($text{'conf_hardcore'},
	&ui_yesno_radio("hardcore", lc($hardcore) eq "true"));

# Online mode
my $online = &find_value("online-mode", $conf) || "true";
print &ui_table_row($text{'conf_online'},
	&ui_yesno_radio("online", lc($online) eq "true"));

# Allow player vs player
my $pvp = &find_value("pvp", $conf) || "true";
print &ui_table_row($text{'conf_pvp'},
	&ui_yesno_radio("pvp", lc($pvp) eq "true"));

print &ui_table_hr();

#### Server options

# Max players
my $players = &find_value("max-players", $conf) || 20;
print &ui_table_row($text{'conf_players'},
	&ui_textbox("players", $players, 5));

# Message of the day
my $motd = &find_value("motd", $conf);
print &ui_table_row($text{'conf_motd'},
	&ui_opt_textbox("motd", $motd, 60,
		$text{'default'}." (A Minecraft Server)<br>",
		$text{'conf_motdmsg'}), 3);

# Max build height
my $build = &find_value("max-build-height", $conf) || 256;
print &ui_table_row($text{'conf_build'},
	&ui_textbox("build", $build, 5));

# Max time between ticks
my $ticks = &find_value("max-tick-time", $conf);
$ticks /= 1000.0 if ($ticks > 0);
print &ui_table_row($text{'conf_ticks'},
	&ui_opt_textbox("ticks", $ticks, 5, $text{'default'}." (60s)").
	" ".$text{'conf_ticksecs'}, 3);

print &ui_table_hr();

#### Spawn options

# Spawn various creatures
foreach my $s ("animals", "monsters", "npcs") {
	my $spawn = &find_value("spawn-$s", $conf) || "true";
	print &ui_table_row($text{'conf_'.$s},
		&ui_yesno_radio($s, lc($spawn) eq "true"));
	}

# Spawn protection range
my $protect = &find_value("spawn-protection", $conf) || 16;
print &ui_table_row($text{'conf_protect'},
	&ui_textbox("protect", $protect, 5));

print &ui_table_hr();

#### Network options

# Listen on IP
my $ip = &find_value("server-ip", $conf);
print &ui_table_row($text{'conf_ip'},
	&ui_opt_textbox("ip", $ip, 15, $text{'conf_allip'}));

# Listen on port
my $port = &find_value("server-port", $conf);
print &ui_table_row($text{'conf_port'},
	&ui_opt_textbox("port", $port, 5, $text{'default'}." (25565)"));

# Allow query port
my $query = &find_value("enable-query", $conf) || "false";
print &ui_table_row($text{'conf_query'},
	&ui_yesno_radio("query", lc($query) eq "true"));

# Allow remote console port
my $rcon = &find_value("enable-rcon", $conf) || "false";
print &ui_table_row($text{'conf_rcon'},
	&ui_yesno_radio("rcon", lc($rcon) eq "true"));

#### Server command-line flags

print &ui_table_row($text{'conf_args'},
	&ui_textbox("args", $config{'java_args'}, 70), 3);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

