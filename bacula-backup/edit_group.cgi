#!/usr/local/bin/perl
# Show the details of one node group, which is actually a special client

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@groups = &find("Client", $conf);
@catalogs = map { $n=&find_value("Name", $_->{'members'}) }
	        &find("Catalog", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'group_title1'}, "");
	$mems = [ { 'name' => 'FDPort',
		    'value' => 9102 },
		  { 'name' => 'Catalog',
		    'value' => $catalogs[0] },
		  { 'name' => 'File Retention',
		    'value' => '30 days' },
		  { 'name' => 'Job Retention',
		    'value' => '6 months' },
		];
	$group = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'group_title2'}, "");
	$group = &find_by("Name", "ocgroup_".$in{'name'}, \@groups);
	$group || &error($text{'group_egone'});
	$mems = $group->{'members'};
	}

# Get node group
@nodegroups = &list_node_groups();
$ngname = $in{'name'} || $in{'new'};
($nodegroup) = grep { $_->{'name'} eq $ngname } @nodegroups;

# Show details
print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'group_header'}, "width=100%", 4);

# Group name
print &ui_table_row($text{'group_name'},
		    $in{'new'} || $in{'name'});

# Password for remote
print &ui_table_row($text{'client_pass'},
	&ui_textbox("pass", $pass=&find_value("Password", $mems), 60), 3);

# FD port
print &ui_table_row($text{'client_port'},
	&ui_textbox("port", $port=&find_value("FDPort", $mems), 6), 3);

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

# Members
print &ui_table_row($text{'group_members'},
		    join(", ", @{$nodegroup->{'members'}}), 3);

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_groups.cgi", $text{'groups_return'});

