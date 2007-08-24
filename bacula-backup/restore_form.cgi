#!/usr/local/bin/perl
# Show a form for restoring an old backup job

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'restore_title'}, "", "restore");

$conf = &get_director_config();
@jobs = &find("Job", $conf);
$backup = &find_by("Type", "Restore", \@jobs);

print &ui_form_start("restore.cgi", "post");
print &ui_table_start($text{'restore_header'}, undef, 2);

# Old job to restore
$dbh = &connect_to_database();
$cmd = $dbh->prepare("select JobId,Name,SchedTime,Level from Job where Name not like 'Restore%' order by SchedTime desc") ||
                &error("prepare failed : ",$dbh->errstr);
$cmd->execute();
while(my ($id, $name, $when, $level) = $cmd->fetchrow()) {
	$level = $text{'restore_level_'.$level} || $level;
	($j, $c) = &is_oc_object($name);
	if (!$j) {
		# Normal backup
		push(@opts, [ $id, "$id - $name ($when) - $level" ]);
		}
	elsif ($j && $c) {
		# Backup of one node
		push(@opts, [ $id, "$id - $j on $c ($when) - $level" ]);

		# Save the job ID to a list of those for this particular node
		# group backup
		$stime = &date_to_unix($when);
		$found = 0;
		foreach $nj (@nodejobs) {
			$diff = abs($stime - $nj->{'stime'});
			if ($nj->{'job'} eq $j && $diff < 30) {
				push(@{$nj->{'clients'}}, [ $id, $c ]);
				$found = 1;
				last;
				}
			}
		if (!$found) {
			push(@nodejobs, { 'job' => $j,
					  'stime' => $stime,
					  'when' => $when,
					  'clients' => [ [ $id, $c ] ]});
			}
		}
	}
# Add entries for entire node group restores
if (@nodejobs) {
	@opts = ( [ undef, $text{'restore_jlist'} ], @opts,
		  [ undef, $text{'restore_njlist'} ] );
	foreach $nj (@nodejobs) {
		push(@opts, [ "nj_".$nj->{'job'}."_".$nj->{'stime'}."_".
				$nj->{'clients'}->[0]->[0],
			      "$nj->{'job'} ($nj->{'when'}" ]);
		}
	}
$cmd->finish();
print &ui_table_row($text{'restore_job'},
		    &ui_select("job", undef, \@opts));

# Files to restore
print &ui_table_row($text{'restore_files'},
		    &ui_textarea("files", undef, 8, 50)."\n".
		    &bacula_file_button("files", "job"));

# Storage device
@storages = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		 &get_bacula_storages();
print &ui_table_row($text{'restore_storage'},
	&ui_select("storage", undef,
	 [ map { [ $_->{'name'},
		   &text('storagestatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @storages ]));

# Destination client or group
@clients = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		grep { !&is_oc_object($_, 1) } &get_bacula_clients();
@groups = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		grep { &is_oc_object($_, 1) } &get_bacula_clients();
@opts = ( );
if (@clients) {
	push(@opts, [ undef, $text{'restore_clist'} ]) if (@groups);
	push(@opts,
	   map { [ $_->{'name'},
		   &text('clientstatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @clients);
	}
if (@groups) {
	push(@opts, [ undef, $text{'restore_glist'} ]) if (@clients);
	push(@opts,
	   map { ($g, $c) = &is_oc_object($_);
		 $c ? ( ) : ( [ $_->{'name'}, $g ] ) } @groups);
	}
if (@nodejobs) {
	push(@opts, [ "*", $text{'restore_all'} ]);
	}
print &ui_table_row($text{'restore_client'},
		    &ui_select("client", undef, \@opts));

# Destination directory
$where = &find_value("Where", $backup->{'members'});
print &ui_table_row($text{'restore_where'},
		    &ui_opt_textbox("where", undef, 40,
				    $text{'default'}." (<tt>$where</tt>)<br>",
				    $text{'restore_where2'}));

# Wait for completion?
print &ui_table_row($text{'backup_wait'},
		    &ui_yesno_radio("wait", $config{'wait'}));

print &ui_table_end();
print &ui_form_end([ [ "restore", $text{'restore_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

