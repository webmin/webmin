#!/usr/local/bin/perl
# edit_group.cgi
# Show a form for editing an existing groups

require './samba-lib.pl';

$access{'maint_groups'} || &error($text{'groups_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'gedit_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	@groups = &list_groups();
	$group = $groups[$in{'idx'}];
	}

print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'gedit_header'}, undef, 2);

print &ui_table_row($text{'gedit_name'},
	$in{'new'} ? &ui_textbox("name", undef, 20)
		   : "<tt>".&html_escape($group->{'name'})."</tt>");

print &ui_table_row($text{'gedit_type'},
	&ui_select("type", $group->{'type'},
		   [ map { [ $_, $text{'groups_type_'.$_} ] }
		         ('l', 'd', 'b', 'u') ]), 1, 0,
		   !$in{'new'});

print &ui_table_row($text{'gedit_unix'},
	$group->{'unix'} == -1 ?
		&ui_opt_textbox("unix", undef, 20, $text{'gedit_none'},
				$text{'gedit_unixgr'})." ".
		  &group_chooser_button("unix") :
		&ui_textbox("unix", $group->{'unix'}, 20)." ".
		  &group_chooser_button("unix"));

print &ui_table_row($text{'gedit_desc'},
	&ui_textbox("desc", $group->{'desc'}, 40));

if ($in{'new'}) {
	print &ui_table_row($text{'gedit_priv'},
		&ui_opt_textbox("priv", undef, 50, $text{'gedit_none'},
				$text{'gedit_set'}));
	}
else {
	print &ui_table_row($text{'gedit_sid'},
		"<tt>".&html_escape($group->{'sid'})."</tt>");

	print &ui_table_row($text{'gedit_priv'},
		"<tt>".($group->{'priv'} || $text{'gedit_none'})."</tt>");
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_groups.cgi", $text{'groups_return'});

