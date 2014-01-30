#!/usr/local/bin/perl
# table_form.cgi
# Display a form for creating a table

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});

# Redirect to other pages depending on button
if ($in{'addview'}) {
	&redirect("edit_view.cgi?new=1&db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'dropdb'}) {
	&redirect("drop_dbase.cgi?db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'backupdb'}) {
	&redirect("backup_form.cgi?db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'exec'}) {
	&redirect("exec_form.cgi?db=".&urlize($in{'db'}));
	return;
	}

$access{'edonly'} && &error($text{'dbase_ecannot'});
$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $text{'table_title2'}, "", "table_form");

print &ui_form_start("create_table.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_table_start($text{'table_header2'}, undef, 2);

print &ui_table_row($text{'table_name'},
		    &ui_textbox("name", undef, 30));

@dbs = grep { &can_edit_db($_) } &list_databases();
if (@dbs > $max_dbs) {
	# Enter source table name manually
	print &ui_table_row($text{'table_copy2'},
		&ui_select("copydb", $in{'db'}, \@dbs).
		" $text{'table_copy2t'} ".
		&ui_textbox("copytable", undef, 20));
	}
else {
	# Show all tables in all DBs
	foreach $d (@dbs) {
		foreach $t (&list_tables($d, 1)) {
			push(@tables, [ "$d.$t" ]);
			}
		}
	print &ui_table_row($text{'table_copy'},
			    &ui_select("copy", undef,
				       [ [ "", $text{'table_copynone'} ],
					 @tables ]));
	}

print &ui_table_row($text{'table_type'},
		    &ui_select("type", "",
		      [ [ "", $text{'default'} ], [ "isam" ], [ "myisam" ],
			[ "heap" ], [ "merge" ], [ "innodb" ], [ "ndbcluster" ]
		      ]));

print &ui_table_row(undef, &show_table_form($in{"fields"} || 4), 2);

print &ui_table_end();
print &ui_form_end([ [ "create", $text{'create'} ] ]);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		 &get_databases_return_link($in{'db'}), $text{'index_return'});

