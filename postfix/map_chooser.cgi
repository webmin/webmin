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
print &ui_hidden("map", $in{'map'});
print &ui_hidden("mapname", $in{'mapname'});
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
	if ($t eq "mysql") {
		$myconf = &get_backend_config($tv->[1]);
		}
	else {
		$myconf = { };
		}
	$mtable = &ui_table_start(undef, "width=100%", 2,
				  [ "nowrap", "nowrap" ]);
	$mtable .= &ui_table_row($text{'chooser_mhosts'},
		&ui_opt_textbox("mhosts_$i", $myconf->{'hosts'}, 30,
				"<tt>localhost</tt>"));
	$mtable .= &ui_table_row($text{'chooser_muser'},
		&ui_textbox("muser_$i", $myconf->{'user'}, 30));
	$mtable .= &ui_table_row($text{'chooser_mpassword'},
		&ui_textbox("mpassword_$i", $myconf->{'password'}, 30));
	$mtable .= &ui_table_row($text{'chooser_mdbname'},
		&ui_textbox("mdbname_$i", $myconf->{'dbname'}, 30));
	if ($postfix_version >= 2.2) {
		# Can use custom query
		$mtable .= &ui_table_row($text{'chooser_mquery'},
			&ui_opt_textbox("mquery_$i", $myconf->{'query'}, 40,
					$text{'chooser_none'}));
		}
	$mtable .= &ui_table_row($text{'chooser_mtable'},
		&ui_textbox("mtable_$i", $myconf->{'table'}, 30));
	$mtable .= &ui_table_row($text{'chooser_mwhere_field'},
		&ui_textbox("mwhere_field_$i", $myconf->{'where_field'}, 30));
	$mtable .= &ui_table_row($text{'chooser_mselect_field'},
		&ui_textbox("mselect_field_$i", $myconf->{'select_field'}, 30));
	$mtable .= &ui_table_row($text{'chooser_madditional_conditions'},
		&ui_opt_textbox("madditional_conditions_$i",
			$myconf->{'additional_conditions'}, 30,
			$text{'chooser_none'}));
	$mtable .= &ui_table_end();

	# For LDAP, read config and generate inputs too
	# XXX

	# Generate possible modes
	@opts = ( );
	push(@opts, [ "", $text{'chooser_none'} ]);
	push(@opts, [ "hash", $text{'chooser_hash'},
	    &ui_textbox("hash_$i", $t eq "hash" ? $tv->[1] : undef, 50) ]);
	push(@opts, [ "regexp", $text{'chooser_regexp'},
	    &ui_textbox("regexp_$i", $t eq "regexp" ? $tv->[1] : undef, 50) ]);
	push(@opts, [ "mysql", $text{'chooser_mysql'}, $mtable ]);
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

