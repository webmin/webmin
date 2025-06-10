#!/usr/local/bin/perl
# Show the details of one file fdirector daemon

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_file_config();
@fdirectors = &find("Director", $conf);

if ($in{'new'}) {
	&ui_print_header(undef, $text{'fdirector_title1'}, "");
	$mems = [ ];
	$fdirector = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'fdirector_title2'}, "");
	$fdirector = &find_by("Name", $in{'name'}, \@fdirectors);
	$fdirector || &error($text{'fdirector_egone'});
	$mems = $fdirector->{'members'};
	}

# Show details
print &ui_form_start("save_fdirector.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'fdirector_header'}, "width=100%", 4);

# Director name
print &ui_table_row($text{'fdirector_name'},
	&ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Password for remote
print &ui_table_row($text{'fdirector_pass'},
	&ui_textbox("pass", $pass=&find_value("Password", $mems), 60), 3);

# Monitor mode
print &ui_table_row($text{'fdirector_monitor'},
	&bacula_yesno("monitor", "Monitor", $mems));

&show_tls_directives($fdirector);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_fdirectors.cgi", $text{'fdirectors_return'});

