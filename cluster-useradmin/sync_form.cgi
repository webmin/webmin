#!/usr/local/bin/perl
# sync_form.cgi
# Display a form for creating some or all missing users and groups on
# some or all servers

require './cluster-useradmin-lib.pl';
&ui_print_header(undef, $text{'sync_title'}, "");

print "$text{'sync_desc'}<p>\n";

print &ui_form_start("sync.cgi", "post");
print &ui_table_start($text{'sync_hosts'}, undef, 2);

# Hosts to sync
print &ui_table_row($text{'sync_hosts'},
	&create_on_input(1, 1));

# Users to sync
print &ui_table_row($text{'sync_users'},
	&ui_radio_table("users_mode", 0,
		[ [ 1, $text{'sync_uall'} ],
		  [ 0, $text{'sync_unone'} ],
		  [ 2, $text{'sync_usel'}, &ui_users_textbox("usel") ],
		  [ 3, $text{'sync_unot'}, &ui_users_textbox("unot") ],
		  [ 4, $text{'sync_uuid'}, &ui_textbox("uuid1", "", 6)." - ".
					   &ui_textbox("uuid2", "", 6) ],
		  [ 5, $text{'sync_ugid'}, &ui_group_textbox("ugid") ],
		]));

# Groups to sync
print &ui_table_row($text{'sync_groups'},
	&ui_radio_table("groups_mode", 0,
		[ [ 1, $text{'sync_gall'} ],
		  [ 0, $text{'sync_gnone'} ],
		  [ 2, $text{'sync_gsel'}, &ui_groups_textbox("gsel") ],
		  [ 3, $text{'sync_gnot'}, &ui_groups_textbox("gnot") ],
		  [ 4, $text{'sync_ggid'}, &ui_textbox("ggid1", "", 6)." - ".
                                           &ui_textbox("ggid2", "", 6) ],
		]));

# Test mode?
print &ui_table_row($text{'sync_test'},
	&ui_yesno_radio("test", 0));

# Create home dir?
print &ui_table_row($text{'sync_makehome'},
	&ui_yesno_radio("makehome", 1));

# Copy home dir files?
print &ui_table_row($text{'sync_copy'},
	&ui_yesno_radio("copy_files", 1));

# Create in other modules?
print &ui_table_row($text{'sync_others'},
	&ui_yesno_radio("others", 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'sync_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

