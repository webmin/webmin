#!/usr/local/bin/perl
# edit_file.cgi
# Display a file editor and its options

require './custom-lib.pl';
&ReadParse();

$access{'edit'} || &error($text{'file_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'fcreate_title'}, "", "fcreate");
	if ($in{'clone'}) {
		$edit = &get_command($in{'id'}, $in{'idx'});
		}
	}
else {
	&ui_print_header(undef, $text{'fedit_title'}, "", "fedit");
	$edit = &get_command($in{'id'}, $in{'idx'});
	}

print &ui_form_start("save_file.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $edit->{'id'});
print &ui_table_start($text{'file_details'}, "width=100%", 2);

if (!$in{'new'}) {
	print &ui_table_row(&hlink($text{'file_id'}, "fileid"),
		"<tt>$edit->{'id'}</tt>");
	}

# Description, text and HTML
print &ui_table_row(&hlink($text{'edit_desc'}, "desc"),
	&ui_textbox("desc", $edit->{'desc'}, 60));
print &ui_table_row(&hlink($text{'edit_desc2'}, "desc2"),
	&ui_textarea("html", $edit->{'html'}, 2, 60));

# File to edit, and environment checkbox
print &ui_table_row(&hlink($text{'file_edit'}, "file"),
	&ui_textbox("edit", $edit->{'edit'}, 60)." ".
	&file_chooser_button("edit", 0)."<br>".
	&ui_checkbox("envs", 1, $text{'file_envs'}, $edit->{'envs'}));

# File owner and group
print &ui_table_row(&hlink($text{'file_owner'}, "owner"),
	&ui_radio("owner_def", $edit->{'user'} ? 0 : 1,
		  [ [ 1, $text{'file_leave'} ],
		    [ 0, $text{'file_user'}." ".
			 &ui_textbox("user", $edit->{'user'}, 13)." ".
			 $text{'file_group'}." ".
			 &ui_textbox("group", $edit->{'group'}, 13) ] ]));

# File permissions
print &ui_table_row(&hlink($text{'file_perms'}, "perms"),
	&ui_opt_textbox("perms", $edit->{'perms'}, 3, $text{'file_leave'},
			$text{'file_set'}));

# Commands to run before and after
print &ui_table_row(&hlink($text{'file_beforeedit'}, "beforeedit"),
	&ui_textbox("beforeedit", $edit->{'beforeedit'}, 60));
print &ui_table_row(&hlink($text{'file_before'}, "before"),
	&ui_textbox("before", $edit->{'before'}, 60));
print &ui_table_row(&hlink($text{'file_after'}, "after"),
	&ui_textbox("after", $edit->{'after'}, 60));

# Command ordering on main page
print &ui_table_row(&hlink($text{'edit_order'},"order"),
	&ui_opt_textbox("order", $edit->{'order'} || "", 6, $text{'default'}));

# Visible in Usermin?
print &ui_table_row(&hlink($text{'edit_usermin'},"usermin"),
	&ui_yesno_radio("usermin", $edit->{'usermin'}));

print &ui_table_end();

# Show parameters
&show_params_inputs($edit, 1, 1);

if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'clone', $text{'edit_clone'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

