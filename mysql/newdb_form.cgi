#!/usr/local/bin/perl
# newdb_form.cgi
# Display a form for creating a new database

require './mysql-lib.pl';
$access{'create'} || &error($text{'newdb_ecannot'});
&ui_print_header(undef, $text{'newdb_title'}, "", "newdb_form");

print &ui_form_start("newdb.cgi", "post");
print &ui_table_start($text{'newdb_header'}, undef, 2);

# DB name
print &ui_table_row($text{'newdb_db'},
	&ui_textbox("db", undef, 20));

if (&compare_version_numbers($mysql_version, "4.1") >= 0) {
	# Character set option
	@charsets = &list_character_sets();
	%csmap = map { $_->[0], $_->[1] } @charsets;
	print &ui_table_row($text{'newdb_charset'},
		     &ui_select("charset", undef,
				[ [ undef, "&lt;$text{'default'}&gt;" ],
				  map { [ $_->[0], $_->[0]." (".$_->[1].")" ] }
				      @charsets ]));
	}

@coll = &list_collation_orders();
if (@coll) {
	# Collation order option
	print &ui_table_row($text{'newdb_collation'},
		     &ui_select("collation", undef,
			[ [ undef, "&lt;$text{'default'}&gt;" ],
			  map { [ $_->[0], $_->[0]." (".$csmap{$_->[1]}.")" ] }
			      &list_collation_orders() ]));
	}

# Initial table name
print &ui_table_row($text{'newdb_table'},
	&ui_radio("table_def", 1, [ [ 1, $text{'newdb_none'} ],
				    [ 0, $text{'newdb_tname'} ] ])." ".
	&ui_textbox("table", undef, 20)." ".$text{'newdb_str'}."...");
print &ui_table_row(undef, &show_table_form(4), 2);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

