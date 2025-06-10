#!/usr/local/bin/perl
# Show the details of one device device

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_storage_config();
@devices = &find("Device", $conf);

if ($in{'new'}) {
	&ui_print_header(undef, $text{'device_title1'}, "");
	$mems = [ { 'name' => 'Media Type',
		    'value' => 'File' },
		  { 'name' => 'LabelMedia',
		    'value' => 'yes' },
		  { 'name' => 'Random Access',
		    'value' => 'yes' },
		  { 'name' => 'AutomaticMount',
		    'value' => 'yes' },
		  { 'name' => 'RemovableMedia',
		    'value' => 'no' },
		  { 'name' => 'AlwaysOpen',
		    'value' => 'no' },
		];
	$device = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'device_title2'}, "");
	$device = &find_by("Name", $in{'name'}, \@devices);
	$device || &error($text{'device_egone'});
	$mems = $device->{'members'};
	}

# Show details
print &ui_form_start("save_device.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'device_header'}, "width=100%", 4);

# Device name
print &ui_table_row($text{'device_name'},
	&ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Archive device or file
print &ui_table_row($text{'device_device'},
	&ui_textbox("device", $device=&find_value("Archive Device", $mems), 40)." ".
	&file_chooser_button("device", 0), 3);

# Media type
print &ui_table_row($text{'device_media'},
	&ui_textbox("media", $media=&find_value("Media Type", $mems), 20));

# Various yes/no options
print &ui_table_row($text{'device_label'},
	&bacula_yesno("label", "LabelMedia", $mems));
print &ui_table_row($text{'device_random'},
	&bacula_yesno("random", "Random Access", $mems));
print &ui_table_row($text{'device_auto'},
	&bacula_yesno("auto", "AutomaticMount", $mems));
print &ui_table_row($text{'device_removable'},
	&bacula_yesno("removable", "RemovableMedia", $mems));
print &ui_table_row($text{'device_always'},
	&bacula_yesno("always", "AlwaysOpen", $mems));

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_devices.cgi", $text{'devices_return'});

