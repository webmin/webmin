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
				     "width=100%", 2, "section$i",
				     $tv->[0] || $i == 0, [ "width=30%" ]);

	# Work out type
	$t = $tv->[0] eq "" ? "" :
	     $tv->[0] eq "hash" ? "hash" :
	     $tv->[0] eq "regexp" ? "regexp" :
	     $tv->[0] eq "pcre" && &supports_map_type("pcre") ? "pcre" :
	     $tv->[0] eq "mysql" && &supports_map_type("mysql") &&
	      $tv->[1] =~ /^[\/\.]/ ? "mysql" :
	     $tv->[0] eq "mysql" && &supports_map_type("mysql") &&
	      $tv->[1] !~ /^[\/\.]/ ? "mysqlsrc" :
	     $tv->[0] eq "ldap" && &supports_map_type("ldap") ? "ldap" :
				    "other";

	# For MySQL, read config file and generate inputs
	$myconf = { };
	if ($t eq "mysql") {
		$myconf = &get_backend_config($tv->[1]);
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
	if (&compare_version_numbers($postfix_version, 2.2) >= 0) {
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
	$lconf = { };
	if ($t eq "ldap") {
		$lconf = &get_backend_config($tv->[1]);
		}
	$ltable = &ui_table_start(undef, "width=100%", 2,
				  [ "nowrap", "nowrap" ]);
	$ltable .= &ui_table_row($text{'chooser_lserver_host'},
		&ui_opt_textbox("lserver_host_$i", $lconf->{'server_host'}, 30,
				"<tt>localhost</tt>"));
	$ltable .= &ui_table_row($text{'chooser_lserver_port'},
		&ui_opt_textbox("lserver_port_$i", $lconf->{'server_port'}, 5,
				"$text{'default'} (389)"));
	$ltable .= &ui_table_row($text{'chooser_lstart_tls'},
		&ui_radio("lstart_tls_$i", $lconf->{'start_tls'} || 'no',
			  [ [ 'yes', $text{'yes'} ],
			    [ 'no', $text{'no'} ] ]));
	$ltable .= &ui_table_row($text{'chooser_lsearch_base'},
		&ui_textbox("lsearch_base_$i", $lconf->{'search_base'}, 50));
	$ltable .= &ui_table_row($text{'chooser_lquery_filter'},
		&ui_opt_textbox("lquery_filter_$i", $lconf->{'query_filter'},50,
		    "$text{'default'} (<tt>mailacceptinggeneralid=%s</tt>)<br>",
		    $text{'chooser_lfilter'}));
	$ltable .= &ui_table_row($text{'chooser_lresult_attribute'},
		&ui_opt_textbox("lresult_attribute_$i",
				$lconf->{'result_attribute'}, 20,
				"$text{'default'} (<tt>maildrop</tt>)<br>",
				$text{'chooser_lattribute'}));
	$ltable .= &ui_table_row($text{'chooser_lscope'},
		&ui_select("lscope_$i", $lconf->{'scope'},
			   [ [ "", "$text{'default'} ($text{'chooser_lsub'})" ],
			     map { [ $_, $text{'chooser_l'.$_} ] }
				 ('sub', 'base', 'one') ]));
	$ltable .= &ui_table_row($text{'chooser_lbind'},
		&ui_radio("lbind_$i", $lconf->{'bind'} || 'yes',
			  [ [ 'yes', $text{'yes'} ],
			    [ 'no', $text{'no'} ] ]));
	$ltable .= &ui_table_row($text{'chooser_lbind_dn'},
		&ui_opt_textbox("lbind_dn_$i", $lconf->{'bind_dn'}, 40,
				$text{'chooser_none'}));
	$ltable .= &ui_table_row($text{'chooser_lbind_pw'},
		&ui_opt_textbox("lbind_pw_$i", $lconf->{'bind_pw'}, 20,
				$text{'chooser_none'}));
	$ltable .= &ui_table_end();

	# Generate possible modes
	@opts = ( );
	push(@opts, [ "", $text{'chooser_none'} ]);
	push(@opts, [ "hash", $text{'chooser_hash'},
	    &ui_textbox("hash_$i", $t eq "hash" ? $tv->[1] : undef, 50) ]);
	push(@opts, [ "regexp", $text{'chooser_regexp'},
	    &ui_textbox("regexp_$i", $t eq "regexp" ? $tv->[1] : undef, 50) ]);
	if (&supports_map_type("pcre")) {
		push(@opts, [ "pcre", $text{'chooser_pcre'},
		    &ui_textbox("pcre_$i",
				$t eq "pcre" ? $tv->[1] : undef, 50) ]);
		}
	if (&supports_map_type("mysql")) {
		push(@opts, [ "mysql", $text{'chooser_mysql'}, $mtable ]);
		if (@sources || $t eq "mysqlsrc") {
			push(@opts, [ "mysqlsrc", $text{'chooser_mysqlsrc'},
				      &ui_select("mysqlsrc_$i",
					 $t eq "mysqlsrc" ? $tv->[1] : undef,
					 \@sources) ]);
			}
		}
	if (&supports_map_type("ldap")) {
		push(@opts, [ "ldap", $text{'chooser_ldap'}, $ltable ]);
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

