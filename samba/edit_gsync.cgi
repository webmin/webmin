#!/usr/local/bin/perl
# edit_gsync.cgi
# Allow the user to edit auto updating of Samba groups by useradmin

require './samba-lib.pl';

$access{'maint_gsync'} || &error($text{'gsync_ecannot'});
&ui_print_header(undef, $text{'gsync_title'}, "");

&check_group_enabled($text{'gsync_cannot'});

print $text{'gsync_msg'}, "<p>\n";

print &ui_form_start("save_gsync.cgi", "post");
print &ui_table_start(undef, undef, 2);

@grid = ( $text{'gsync_type'},
	    &ui_select("type", $config{'gsync_type'},
		       [ map { [ $_, $text{'groups_type_'.$_} ] }
			     ('l', 'd', 'b', 'u') ]),
	  $text{'gsync_priv'},
	    &ui_textbox("priv", $config{'gsync_priv'}, 40),
	);
print &ui_table_row($text{'gsync_add'},
	&ui_yesno_radio("add", $config{'gsync_add'}).
	"<br>\n".
	&ui_grid_table(\@grid, 2));

print &ui_table_row($text{'gsync_chg'},
	&ui_yesno_radio("change", $config{'gsync_change'}));

print &ui_table_row($text{'gsync_del'},
	&ui_yesno_radio("delete", $config{'gsync_delete'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'gsync_apply'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

