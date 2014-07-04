#!/usr/local/bin/perl
# Show a list of all backup jobs

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'jobs_title'}, "", "jobs");

$conf = &get_director_config();
@jobs = grep { !&is_oc_object($_) }
	     ( &find("JobDefs", $conf), &find("Job", $conf) );
&sort_by_name(\@jobs);
if (@jobs) {
	print &ui_form_start("delete_jobs.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_job.cgi?new=1",$text{'jobs_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=10%", "width=20%", "width=20%",
		 "width=20%" );
	print &ui_columns_start([ "", $text{'jobs_name'},
				  $text{'jobs_deftype'},
				  $text{'jobs_type'},
				  $text{'jobs_client'},
				  $text{'jobs_fileset'},
				  $text{'jobs_schedule'}, ], "100%", 0, \@tds);
	foreach $f (@jobs) {
		$name = &find_value("Name", $f->{'members'});
		$type = &find_value("Type", $f->{'members'});
		$client = &find_value("Client", $f->{'members'});
		$fileset = &find_value("FileSet", $f->{'members'});
		$schedule = &find_value("Schedule", $f->{'members'});
		print &ui_checked_columns_row([
			&ui_link("edit_job.cgi?name=".&urlize($name), $name),
			$f->{'name'} eq 'Job' ? $text{'no'} : $text{'yes'},
			$type || "<i>$text{'default'}</i>",
			$client || "<i>$text{'default'}</i>",
			$fileset || "<i>$text{'default'}</i>",
			$schedule || "<i>$text{'default'}</i>",
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'jobs_delete'} ] ]);
	}
else {
	print "<b>$text{'jobs_none'}</b><p>\n";
	print &ui_link("edit_job.cgi?new=1",$text{'jobs_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

