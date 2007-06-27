#!/usr/local/bin/perl
# Show the details of one client

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@clients = &find("Client", $conf);
@catalogs = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Catalog", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'client_title1'}, "");
	$mems = [ { 'name' => 'FDPort',
		    'value' => 9102 },
		  { 'name' => 'Catalog',
		    'value' => $catalogs[0] },
		  { 'name' => 'File Retention',
		    'value' => '30 days' },
		  { 'name' => 'Job Retention',
		    'value' => '6 months' },
		];
	$client = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'client_title2'}, "");
	$client = &find_by("Name", $in{'name'}, \@clients);
	$client || &error($text{'client_egone'});
	$mems = $client->{'members'};
	}

# Show details
print &ui_form_start("save_client.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'client_header'}, "width=100%", 4);

# Client name
print &ui_table_row($text{'client_name'},
	&ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Password for remote
print &ui_table_row($text{'client_pass'},
	&ui_textbox("pass", $pass=&find_value("Password", $mems), 60), 3);

# Connection details
print &ui_table_row($text{'client_address'},
	&ui_textbox("address", $address=&find_value("Address", $mems), 20));
print &ui_table_row($text{'client_port'},
	&ui_textbox("port", $port=&find_value("FDPort", $mems), 6));

# Catalog
print &ui_table_row($text{'client_catalog'},
	&ui_select("catalog", $catalog=&find_value("Catalog", $mems),
		   [ map { [ $_ ] } @catalogs ], 1, 0, 1));

# Prune option
$prune = &find_value("AutoPrune", $mems);
print &ui_table_row($text{'client_prune'},
	&ui_radio("prune", $prune,
		  [ [ "yes", $text{'yes'} ], [ "no", $text{'no'} ],
		    [ "", $text{'default'} ] ]));

# Retention options
$fileret = &find_value("File Retention", $mems);
print &ui_table_row($text{'client_fileret'},
		    &show_period_input("fileret", $fileret));
$jobret = &find_value("Job Retention", $mems);
print &ui_table_row($text{'client_jobret'},
		    &show_period_input("jobret", $jobret));

# SSL options
&show_tls_directives($client);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "status", $text{'client_status'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_clients.cgi", $text{'clients_return'});

