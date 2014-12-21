#!/usr/local/bin/perl
# Show mysql server configuration options

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'cnf_ecannot'});
&ui_print_header(undef, $text{'cnf_title'}, "", "cnf");

# Make sure config exists
$conf = &get_mysql_config();
if (!$conf) {
	print &text('cnf_efile', "<tt>$config{'my_cnf'}</tt>",
		    "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
($mysqld) = grep { $_->{'name'} eq 'mysqld' } @$conf;
$mysqld || &error($text{'cnf_emysqld'});
$mems = $mysqld->{'members'};

print &ui_form_start("save_cnf.cgi", "post");
print &ui_table_start($text{'cnf_header'}, "width=100%", 4);

# Show mysqld section options
$port = &find_value("port", $mems);
print &ui_table_row($text{'cnf_port'},
		    &ui_opt_textbox("port", $port, 5, $text{'default'}));

$bind = &find_value("bind-address", $mems);
print &ui_table_row($text{'cnf_bind'},
		    &ui_opt_textbox("bind", $bind, 20, $text{'cnf_all'}));

print &ui_table_row($text{'cnf_big-tables'},
    &ui_yesno_radio("big-tables", &find("big-tables", $mems) ? 1 : 0));

$socket = &find_value("socket", $mems);
print &ui_table_row($text{'cnf_socket'},
		    &ui_opt_textbox("socket", $socket, 50, $text{'default'}).
		    " ".&file_chooser_button("socket"), 3);

$datadir = &find_value("datadir", $mems);
print &ui_table_row($text{'cnf_datadir'},
		    &ui_opt_textbox("datadir", $datadir, 50, $text{'default'}).
		    " ".&file_chooser_button("datadir"), 3);

$stor = &find_value("default-storage-engine", $mems);
print &ui_table_row($text{'cnf_stor'},
		    &ui_select("stor", $stor,
			       [ [ '', $text{'default'} ],
			         'MyISAM', 'InnoDB', 'MERGE',
				 'NDB', 'ARCHIVE', 'CSV',
				 'BLACKHOLE' ], 1, 0, 1));

$fpt = &find_value("innodb_file_per_table", $mems);
print &ui_table_row($text{'cnf_fpt'},
		    &ui_yesno_radio("fpt", $fpt));

# Show set variables
print &ui_table_hr();

%vars = &parse_set_variables(&find_value("set-variable", $mems));
foreach $v (@mysql_set_variables) {
	print &ui_table_row($text{'cnf_'.$v},
		&ui_radio($v."_def", defined($vars{$v}) ? 0 : 1,
			  [ [ 1, $text{'default'} ], [ 0, " " ] ])."\n".
		&mysql_size_input($v, $vars{$v}), 3);
	}
foreach $v (@mysql_number_variables) {
	$n = &find_value($v, $mems);
	print &ui_table_row($text{'cnf_'.$v},
		&ui_radio($v."_def", defined($n) ? 0 : 1,
			  [ [ 1, $text{'default'} ], [ 0, " " ] ])."\n".
		&ui_textbox($v, $n, 8), 3);
	}
foreach $v (@mysql_byte_variables) {
	$n = &find_value($v, $mems);
	print &ui_table_row($text{'cnf_'.$v},
		&ui_radio($v."_def", defined($n) ? 0 : 1,
			  [ [ 1, $text{'default'} ], [ 0, " " ] ])."\n".
		&mysql_size_input($v, $n), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ],
		     [ "restart", $text{'cnf_restart'} ] ]);

&ui_print_footer("", $text{'index_return'});

