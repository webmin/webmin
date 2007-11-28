#!/usr/local/bin/perl
# table_form.cgi
# Display a form for creating a table

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&ui_print_header(undef, $text{'table_title2'}, "", "table_form");

print &ui_form_start("create_table.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_table_start($text{'table_header2'}, undef, 2);

print &ui_table_row($text{'table_name'},
		    &ui_textbox("name", undef, 30));

foreach $d (&list_databases()) {
	next if (!&can_edit_db($d));
	foreach $t (&list_tables($d, 1)) {
		push(@tables, [ "$d.$t" ]);
		}
	}
print &ui_table_row($text{'table_copy'},
		    &ui_select("copy", undef,
			       [ [ "", $text{'table_copynone'} ],
				 @tables ]));

print &ui_table_row($text{'table_type'},
		    &ui_select("type", "",
			[ [ "", $text{'default'} ], [ "isam" ], [ "myisam" ],
			  [ "heap" ], [ "merge" ], [ "innodb" ], [ "ndbcluster" ]
			]));

print "<tr> <td colspan=2>";
&show_table_form($in{"fields"} || 4);
print "</td> </tr>\n";

print &ui_table_end();
print &ui_form_end([ [ "create", $text{'create'} ] ]);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});

