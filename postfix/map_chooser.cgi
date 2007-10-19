#!/usr/local/bin/perl
# Show a form for selecting the source for a map

require './postfix-lib.pl';
&ReadParse();
&popup_header($text{'chooser_title'});

# Parse into files
@maps = &get_maps_types_files($in{'map'});
push(@maps, [ ]);
@sources = &list_mysql_sources();

print &ui_form_start("map_chooser_save.cgi", "post");
$i = 0;
foreach $tv (@maps) {
	print &ui_hidden_table_start(&text('chooser_header', $i+1),
				     "width=100%", 2, "section$i", $tv->[0],
				     [ "width=30%" ]);

	# Work out type
	$t = $tv->[0] eq "" ? "" :
	     $tv->[0] eq "hash" ? "hash" :
	     $tv->[0] eq "regexp" ? "regexp" :
	     $tv->[0] eq "mysql" && $tv->[1] =~ /^[\/\.]/ ? "mysql" :
	     $tv->[0] eq "mysql" && $tv->[1] !~ /^[\/\.]/ ? "mysqlsrc" :
				    "other";

	# For MySQL, read config file and generate inputs
	# XXX

	# Generate possible modes
	@opts = ( );
	if ($tv->[0] eq "") {
		# Not set yet
		push(@opts, [ "", $text{'chooser_none'} ]);
		}
	push(@opts, [ "hash", $text{'chooser_hash'},
	    &ui_textbox("hash_$i", $t eq "hash" ? $tv->[1] : undef, 50) ]);
	push(@opts, [ "regexp", $text{'chooser_regexp'},
	    &ui_textbox("regexp_$i", $t eq "regexp" ? $tv->[1] : undef, 50) ]);
	push(@opts, [ "mysql", $text{'chooser_mysql'}, $mytable ]);
	if (@sources || $t eq "mysqlsrc") {
		push(@opts, [ "mysqlsrc", $text{'chooser_mysqlsrc'},
			      &ui_select("mysqlsrc_$i",
					 $t eq "mysqlsrc" ? $tv->[1] : undef,
					 \@sources) ]);
		}
	push(@opts, [ "other", $text{'chooser_other'},
	    &ui_textbox("other_$i", $t eq "other" ? $tv->[1] : undef, 60) ]);

	# Display mode selector
	print &ui_table_row(undef,
		&ui_radio_table("type_$i", $t, \@opts), 2);

	print &ui_hidden_table_end();
	$i++;
	}
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&popup_footer();

