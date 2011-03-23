#!/usr/local/bin/perl
# newdb_form.cgi
# Display a form for creating a new database

require './postgresql-lib.pl';
$access{'create'} || &error($text{'newdb_ecannot'});
&ui_print_header(undef, $text{'newdb_title'}, "", "newdb_form");

# Start of form block
print &ui_form_start("newdb.cgi", "post");
print &ui_table_start($text{'newdb_header'}, undef, 2);

# Database name
print &ui_table_row($text{'newdb_db'},
	&ui_textbox("db", undef, 40));

if (&get_postgresql_version() >= 7) {
	# Owner option
	$u = &execute_sql($config{'basedb'}, "select usename from pg_shadow");
	@users = map { $_->[0] } @{$u->{'data'}};
	print &ui_table_row($text{'newdb_user'},
		&ui_radio("user_def", 1,
		    [ [ 1, $text{'default'} ],
		      [ 0, &ui_select("user", undef, \@users) ] ]));
	}

if (&get_postgresql_version() >= 8) {
	# Encoding option
	print &ui_table_row($text{'newdb_encoding'},
		&ui_opt_textbox("encoding", undef, 20, $text{'default'}));
	}

# Path to database file
print &ui_table_row($text{'newdb_path'},
	&ui_opt_textbox("path", undef, 40, $text{'default'}));

# Template DB
print &ui_table_row($text{'newdb_template'},
	&ui_select("template", undef,
		   [ [ undef, "&lt;".$text{'newdb_notemplate'}."&gt;" ],
		     &list_databases() ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

