#!/usr/local/bin/perl
# Show a form for editing server config variables

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text);
my $conf = &get_minecraft_config();

&ui_print_header(undef, $text{'conf_title'}, "");

print &ui_form_start("save_conf.cgi", "post");
print &ui_table_start($text{'conf_header'}, undef, 2);

#### World-related options

# Seed for new worlds
my $seed = &find_value("level-seed", $conf);
print &ui_table_row($text{'conf_seed'},
	&ui_opt_textbox("seed", $seed, 20, $text{'conf_random'}));

# Type for new worlds
my $type = &find_value("level-type", $conf) || "DEFAULT";
print &ui_table_row($text{'conf_type'},
	&ui_select("type", $type,
		[ [ "DEFAULT", $text{'conf_type_default'} ],
		  [ "FLAT", $text{'conf_type_flat'} ],
		  [ "LARGEBIOMES", $text{'conf_type_largebiomes'} ] ]));

# Generate structures in new worlds
my $structs = &find_value("generate-structures", $conf) || "true";
print &ui_table_row($text{'conf_structs'},
	&ui_yesno_radio("structs", lc($structs) eq "true");

# Allow nether
my $nether = &find_value("allow-nether", $conf) || "true";
print &ui_table_row($text{'conf_nether'},
	&ui_yesno_radio("nether", lc($nether) eq "true");

print &ui_table_hr();

#### Game-related options

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

