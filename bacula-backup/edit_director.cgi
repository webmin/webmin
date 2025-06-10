#!/usr/local/bin/perl
# Show the global director configuration

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$director = &find("Director", $conf);
$director || &error($text{'director_enone'});
$mems = $director->{'members'};

@messages = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Messages", $conf);

&ui_print_header(undef, $text{'director_title'}, "", "director");

print &ui_form_start("save_director.cgi", "post");
print &ui_table_start($text{'director_header'}, "width=100%", 4);

$name = &find_value("Name", $mems);
print &ui_table_row($text{'director_name'},
		    &ui_textbox("name", $name, 20));

$port = &find_value("DIRport", $mems);
print &ui_table_row($text{'director_port'},
		    &ui_textbox("port", $port, 6));

$jobs = &find_value("Maximum Concurrent Jobs", $mems);
print &ui_table_row($text{'director_jobs'},
		    &ui_opt_textbox("jobs", $jobs, 6, $text{'default'}));

$messages = &find_value("Messages", $mems);
print &ui_table_row($text{'director_messages'},
	&ui_select("messages", $messages,
		[ [ "", "&lt;$text{'default'}&gt;" ],
		  map { [ $_ ] } @messages ], 1, 0, 1));

$dir = &find_value("WorkingDirectory", $mems);
print &ui_table_row($text{'director_dir'},
		    &ui_textbox("dir", $dir, 60)." ".
		    &file_chooser_button("dir", 1), 3);

# SSL options
&show_tls_directives($director);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

