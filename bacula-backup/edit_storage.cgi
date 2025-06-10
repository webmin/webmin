#!/usr/local/bin/perl
# Show the details of one file storage daemon

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@storages = &find("Storage", $conf);
$sconf = &get_storage_config();
if ($sconf) {
	@devices = map { $n=&find_value("Name", $_->{'members'}) }
			&find("Device", $sconf);
	}

if ($in{'new'}) {
	&ui_print_header(undef, $text{'storage_title1'}, "");
	$mems = [ { 'name' => 'SDPort',
		    'value' => 9103 },
		  { 'name' => 'Address',
		    'value' => &get_system_hostname() },
		  { 'name' => 'Media Type',
		    'value' => 'File' },
		  { 'name' => 'Maximum Concurrent Jobs',
		    'value' => '20' },
		  { 'name' => 'Device',
		    'value' => $devices[0] },
		];
	if (@storages) {
		push(@$mems,
			{ 'name' => 'Password',
			  'value' => &find_value("Password",
					$storages[0]->{'members'})
			});
		}
	$storage = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'storage_title2'}, "");
	$storage = &find_by("Name", $in{'name'}, \@storages);
	$storage || &error($text{'storage_egone'});
	$mems = $storage->{'members'};
	}

# Show details
print &ui_form_start("save_storage.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'storage_header'}, "width=100%", 4);

# Storage name
print &ui_table_row($text{'storage_name'},
	&ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Password for remote
print &ui_table_row($text{'storage_pass'},
	&ui_textbox("pass", $pass=&find_value("Password", $mems), 60), 3);

# Connection details
print &ui_table_row($text{'storage_address'},
	&ui_textbox("address", $address=&find_value("Address", $mems), 20));
print &ui_table_row($text{'storage_port'},
	&ui_textbox("port", $port=&find_value("SDPort", $mems), 6));

# Device name
if (@devices) {
	$device=&find_value("Device", $mems);
	$found = &indexof($device, @devices) >= 0;
	print &ui_table_row($text{'storage_device'},
		&ui_select("device", $found ? $device : "",
			   [ (map { [ $_ ] } @devices),
			     [ "", $text{'storage_other'} ] ])."\n".
		&ui_textbox("other", $found ? "" : $device, 10));
	}
else {
	print &ui_table_row($text{'storage_device'},
		&ui_textbox("device", $device=&find_value("Device",$mems), 20));
	}

# Media type
print &ui_table_row($text{'storage_media'},
	&ui_textbox("media", $media=&find_value("Media Type", $mems), 20));

# Maximum Concurrent Jobs
print &ui_table_row($text{'storage_maxjobs'},
	&ui_textbox("maxjobs", $maxjobs=&find_value("Maximum Concurrent Jobs", $mems), 5));

# SSL options
&show_tls_directives($storage);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "status", $text{'storage_status'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_storages.cgi", $text{'storages_return'});

