#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

&ui_print_header(&text('config_dir', $module_info{'desc'}),
		 $text{'config_title'}, "", $help, 0, 1);
$head = "<link rel='stylesheet' type='text/css' href='unauthenticated/css/style.css' />";
print $head;

if(!-e "$confdir/.config") {
    &read_file("$module_root_directory/defaultuconf", \%config);
} else {
    &read_file("$confdir/.config", \%config);
}

# Load module config user custom manually due to non-standard config
&load_module_preferences($module_name, \%config);

if(!-e "$confdir/.bookmarks") {
    $bookmarks = '';
} else {
    $bookmarks = &read_file_contents($confdir.'/.bookmarks', 1);
}

print &ui_form_start("save_config.cgi", "post");

print &ui_table_start(&text('config_header', $module_info{'desc'}),
		      "width=100%", 2);
print &ui_table_row($text{'config_columns_to_display'},
    &ui_checkbox('columns', 'type', $text{'type'}, $config{'columns'} =~ /type/).
    &ui_checkbox('columns', 'size', $text{'size'}, $config{'columns'} =~ /size/).
    &ui_checkbox('columns', 'owner_user', $text{'ownership'}, $config{'columns'} =~ /owner_user/).
    &ui_checkbox('columns', 'permissions', $text{'permissions'}, $config{'columns'} =~ /permissions/).
    (get_acls_status() ? &ui_checkbox('columns', 'acls', $text{'acls'}, $config{'columns'} =~ /acls/) : undef).
    (get_attr_status() ? &ui_checkbox('columns', 'attributes', $text{'attributes'}, $config{'columns'} =~ /attributes/) : undef).
    (get_selinux_status() ? &ui_checkbox('columns', 'selinux', $text{'selinux'}, $config{'columns'} =~ /selinux/) : undef).
    &ui_checkbox('columns', 'last_mod_time', $text{'last_mod_time'}, $config{'columns'} =~ /last_mod_time/)
);
print &ui_table_row($text{'config_per_page'}, ui_textbox("per_page", $config{'per_page'}, 80));
print &ui_table_row($text{'file_detect_encoding'}, &ui_yesno_radio('config_portable_module_filemanager_editor_detect_encoding', $config{'config_portable_module_filemanager_editor_detect_encoding'} ne 'false' ? 'true' : 'false', 'true', 'false'));
print &ui_table_row($text{'file_showhiddenfiles'}, &ui_yesno_radio('config_portable_module_filemanager_show_dot_files', $config{'config_portable_module_filemanager_show_dot_files'} ne 'false' ? 'true' : 'false', 'true', 'false'));
print &ui_table_row($text{'config_bookmarks'}, &ui_textarea("bookmarks", $bookmarks, 5, 40));

print &ui_table_end();

print &ui_hidden('path', $path);

print &ui_form_end([ [ save, $text{'save'} ] ]);

&ui_print_footer("index.cgi?path=".&urlize($path), $text{'previous_page'});
