#!/usr/local/bin/perl
# Display a form for editing or creating a htgroup entry

require './htaccess-lib.pl';
&ReadParse();
@dirs = &list_directories();
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
&switch_user();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'gedit_title1'}, "");
	$group = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	$groups = &list_groups($dir->[4]);
	$group = $groups->[$in{'idx'}];
	}

print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("dir", $in{'dir'});
print &ui_table_start($text{'gedit_header'}, undef, 2);

# Group name
print &ui_table_row($text{'gedit_group'},
	&ui_textbox("group", $group->{'group'}, 40));

# Enabled?
print &ui_table_row($text{'edit_enabled'},
	&ui_yesno_radio("enabled", $group->{'enabled'} ? 1 : 0));

# List of members
print &ui_table_row($text{'gedit_members'},
	&ui_textarea("members", join("\n", @{$group->{'members'}}), 5, 40));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

