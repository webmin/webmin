#!/usr/local/bin/perl
# Show a form for restoring an old node group backup job

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'grestore_title'}, "", "grestore");

print &ui_form_start("grestore.cgi", "post");
print &ui_table_start($text{'grestore_header'}, undef, 2);

# Old job to restore
$dbh = &connect_to_database();
$cmd = $dbh->prepare("select JobId,Name,SchedTime from Job where Name not like 'Restore%' order by SchedTime desc") ||
                &error("prepare failed : ",$dbh->errstr);
$cmd->execute();
while(my ($id, $name, $when) = $cmd->fetchrow()) {
	if ($oc = &is_oc_object($name)) {
		push(@opts, [ $id, "$oc ($id) ($when)" ]);
		}
	}
$cmd->finish();
print &ui_table_row($text{'restore_job'},
		    &ui_select("job", undef, \@opts));

# Files to restore
print &ui_table_row($text{'restore_files'},
		    &ui_textarea("files", undef, 8, 50)."\n".
		    &bacula_file_button("files", "job"));

# Destination client
@clients = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		grep { &is_oc_object($_, 1) } &get_bacula_clients();
print &ui_table_row($text{'restore_client'},
	&ui_select("client", undef,
	 [ map { [ $_->{'name'},
		   &text('clientstatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @clients ]));

# Storage device
@storages = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		&get_bacula_storages();
print &ui_table_row($text{'restore_storage'},
	&ui_select("storage", undef,
	 [ map { [ $_->{'name'},
		   &text('storagestatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @storages ]));

print &ui_table_end();
print &ui_form_end([ [ "restore", $text{'restore_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

