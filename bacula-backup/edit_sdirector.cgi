#!/usr/local/bin/perl
# Show the details of one file daemon director

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_storage_config();
@sdirectors = &find("Director", $conf);

if ($in{'new'}) {
	&ui_print_header(undef, $text{'sdirector_title1'}, "");
	$mems = [ ];
	$sdirector = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'sdirector_title2'}, "");
	$sdirector = &find_by("Name", $in{'name'}, \@sdirectors);
	$sdirector || &error($text{'sdirector_egone'});
	$mems = $sdirector->{'members'};
	}

# Show details
print &ui_form_start("save_sdirector.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'sdirector_header'}, "width=100%", 4);

# Director name
print &ui_table_row($text{'sdirector_name'},
	&ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Password for remote
print &ui_table_row($text{'sdirector_pass'},
	&ui_textbox("pass", $pass=&find_value("Password", $mems), 60), 3);

# Monitor mode
print &ui_table_row($text{'sdirector_monitor'},
	&bacula_yesno("monitor", "Monitor", $mems));

&show_tls_directives($sdirector);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_sdirectors.cgi", $text{'sdirectors_return'});

