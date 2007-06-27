#!/usr/local/bin/perl
# Show the global file daemon configuration

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_file_config();
$file = &find("FileDaemon", $conf);
$file || &error($text{'file_enone'});
$mems = $file->{'members'};

&ui_print_header(undef, $text{'file_title'}, "", "file");

print &ui_form_start("save_file.cgi", "post");
print &ui_table_start($text{'file_header'}, "width=100%", 4);

$name = &find_value("Name", $mems);
print &ui_table_row($text{'file_name'},
		    &ui_textbox("name", $name, 20));

$port = &find_value("FDport", $mems);
print &ui_table_row($text{'file_port'},
		    &ui_textbox("port", $port, 6));

$jobs = &find_value("Maximum Concurrent Jobs", $mems);
print &ui_table_row($text{'file_jobs'},
		    &ui_opt_textbox("jobs", $jobs, 6, $text{'default'}));

$dir = &find_value("WorkingDirectory", $mems);
print &ui_table_row($text{'file_dir'},
		    &ui_textbox("dir", $dir, 60)." ".
		    &file_chooser_button("dir", 1), 3);

# SSL options
&show_tls_directives($file);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

