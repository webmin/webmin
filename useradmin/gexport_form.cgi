#!/usr/local/bin/perl
# Display a form for exporting a batch file of groups

require './user-lib.pl';
$access{'export'} || &error($text{'gexport_ecannot'});
&ui_print_header(undef, $text{'gexport_title'}, "", "gexport");

print "$text{'export_desc'}<p>\n";
print &ui_form_start("gexport_exec.cgi");
print &ui_table_start($text{'gexport_header'}, undef, 2);

# Destination
if ($access{'export'} == 2) {
	# Can be to a file
	print &ui_table_row($text{'export_to'},
		&ui_radio_table("to", 0,
			[ [ 0, $text{'export_show'} ],
			  [ 1, $text{'export_file'},
				&ui_filebox("file", undef, 30) ] ]));
	}
else {
	# Always in browser
	print &ui_table_row($text{'export_to'}, $text{'export_show'});
	}

# Groups to include
print &ui_table_row($text{'gexport_who'},
    &ui_radio_table("mode", 0,
	[ [ 0, $text{'acl_gedit_all'} ],
	  [ 2, $text{'acl_gedit_only'},
	    &ui_textbox("can", undef, 40)." ".
	    &group_chooser_button("can", 1) ],
	  [ 3, $text{'acl_gedit_except'},
	    &ui_textbox("cannot", undef, 40)." ".
	    &group_chooser_button("cannot", 1) ],
	  [ 4, $text{'acl_gedit_gid'},
	    &ui_textbox("gid", undef, 6)." - ".
	    &ui_textbox("gid2", undef, 6) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'export_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

