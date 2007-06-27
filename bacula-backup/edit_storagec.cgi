#!/usr/local/bin/perl
# Show the global storage daemon configuration

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_storage_config();
$storagec = &find("Storage", $conf);
$storagec || &error($text{'storagec_enone'});
$mems = $storagec->{'members'};

@messages = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Messages", $conf);

&ui_print_header(undef, $text{'storagec_title'}, "", "storagec");

print &ui_form_start("save_storagec.cgi", "post");
print &ui_table_start($text{'storagec_header'}, "width=100%", 4);

$name = &find_value("Name", $mems);
print &ui_table_row($text{'storagec_name'},
		    &ui_textbox("name", $name, 20));

$port = &find_value("SDport", $mems);
print &ui_table_row($text{'storagec_port'},
		    &ui_textbox("port", $port, 6));

$jobs = &find_value("Maximum Concurrent Jobs", $mems);
print &ui_table_row($text{'storagec_jobs'},
		    &ui_opt_textbox("jobs", $jobs, 6, $text{'default'}));

$dir = &find_value("WorkingDirectory", $mems);
print &ui_table_row($text{'storagec_dir'},
		    &ui_textbox("dir", $dir, 60)." ".
		    &file_chooser_button("dir", 1), 3);

# SSL options
&show_tls_directives($storagec);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

