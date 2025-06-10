#!/usr/local/bin/perl
# Show a form for running a node group backup job

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'gbackup_title'}, "", "gbackup");

print &ui_form_start("gbackup.cgi", "post");
print &ui_table_start($text{'gbackup_header'}, undef, 2);

# Job to run
$conf = &get_director_config();
foreach $job (&find("JobDefs", $conf)) {
	if ($name = &is_oc_object($job)) {
		$client = &is_oc_object(
			&find_value("Client", $job->{'members'}));
		$fileset = &find_value("FileSet", $job->{'members'});
		push(@sel, [ $name, 
			&text('gbackup_jd', $name, $fileset, $client) ]);
		}
	}
print &ui_table_row($text{'backup_job'},
		    &ui_select("job", undef, \@sel));

print &ui_table_end();
print &ui_form_end([ [ "backup", $text{'backup_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
