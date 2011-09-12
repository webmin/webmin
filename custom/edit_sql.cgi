#!/usr/local/bin/perl
# Display an SQL command

require './custom-lib.pl';
&ReadParse();

# Work out which DBI drivers we have
@drivers = &list_dbi_drivers();
if (!@drivers) {
	# None! Offer to install
	&ui_print_header(undef, $text{'sql_title1'}, "");
	eval "use DBI";
	if ($@) {
		@need = ( "DBI" );
		}
	$myneed = &urlize(join(" ", @need, "DBD::mysql"));
	$pgneed = &urlize(join(" ", @need, "DBD::Pg"));
	print &text('sql_edrivers',
		"../cpan/download.cgi?source=3&cpan=$myneed&return=/$module_name/&returndesc=".&urlize($text{'index_return'}),
		"../cpan/download.cgi?source=3&cpan=$pgneed&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
	}

$access{'edit'} || &error($text{'edit_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'sql_title1'}, "");
	if ($in{'clone'}) {
		$cmd = &get_command($in{'id'}, $in{'idx'});
		}
	}
else {
	&ui_print_header(undef, $text{'sql_title2'}, "");
	$cmd = &get_command($in{'id'}, $in{'idx'});
	}

print &ui_form_start("save_sql.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("id", $cmd->{'id'}),"\n";
print &ui_table_start($text{'sql_header'}, "width=100%", 2);

# Show command info
if (!$in{'new'}) {
	print &ui_table_row($text{'edit_id'}, "<tt>$cmd->{'id'}</tt>");
	}
print &ui_table_row($text{'edit_desc'},
		    &ui_textbox("desc", $cmd->{'desc'}, 50));
print &ui_table_row($text{'edit_desc2'},
		    &ui_textarea("html", $cmd->{'html'}, 2, 50));

# Show databse type and name
print &ui_table_row($text{'sql_type'},
		    &ui_select("type", $cmd->{'type'},
			[ map { [ $_->{'driver'}, $_->{'name'} ] } @drivers ]));
print &ui_table_row($text{'sql_db'},
		    &ui_textbox("db", $cmd->{'db'}, 20));

# Show command to run
print &ui_table_row($text{'sql_cmd'},
		    &ui_textarea("sql", $cmd->{'sql'}, 10, 70));

# Show login and password
print &ui_table_row($text{'sql_user'},
		    &ui_textbox("dbuser", $cmd->{'user'}, 20));
print &ui_table_row($text{'sql_pass'},
		    &ui_password("dbpass", $cmd->{'pass'}, 20));

# Show host to connect to
print &ui_table_row($text{'sql_host'},
		    &ui_opt_textbox("host", $cmd->{'host'}, 20,
				    $text{'sql_local'}));

# Command ordering on main page
print &ui_table_row(&hlink($text{'edit_order'},"order"),
	&ui_opt_textbox("order", $cmd->{'order'} || "", 6, $text{'default'}));

print &ui_table_end(),"<p>\n";

# Show section for parameters
&show_params_inputs($cmd);

# End of form
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ 'clone', $text{'edit_clone'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

