#!/usr/local/bin/perl
# Show the status of the director, including recent jobs

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'dirstatus_title'}, "", "dirstatus");

($sched, $run, $done) = &get_director_status();

# Running jobs
print &ui_subheading($text{'dirstatus_run'});
if (@$run) {
	print &ui_form_start("cancel_jobs.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d") );
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'dirstatus_name'},
				  $text{'dirstatus_id'},
				  $text{'dirstatus_level'},
				  $text{'dirstatus_status'} ], "100%",
				0, \@tds);
	foreach $j (@$run) {
		print &ui_checked_columns_row([
			&joblink($j->{'name'}),
			$j->{'id'},
			$j->{'level'},
			$j->{'status'} ], \@tds, "d", $j->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "cancel", $text{'dirstatus_cancel'} ],
			     [ "refresh", $text{'dirstatus_refresh'} ] ]);
	}
else {
	print "<b>$text{'dirstatus_runnone'}</b><p>\n";
	print &ui_form_start("cancel_jobs.cgi");
	print &ui_form_end([ [ "refresh", $text{'dirstatus_refresh'} ] ]);
	}

# Completed jobs
print &ui_subheading($text{'dirstatus_done'});
if (@$done) {
	print &ui_columns_start([ $text{'dirstatus_name'},
				  $text{'dirstatus_id'},
				  $text{'dirstatus_level'},
				  $text{'dirstatus_date'},
				  $text{'dirstatus_bytes'},
				  $text{'dirstatus_files'},
				  $text{'dirstatus_status2'} ], "100%");
	foreach $j (@$done) {
		print &ui_columns_row([
			&joblink($j->{'name'}),
			$j->{'id'},
			$j->{'level'},
			$j->{'date'},
			&nice_size($j->{'bytes'}),
			$j->{'files'},
			$j->{'status'} ]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'dirstatus_donenone'}</b><p>\n";
	}



# Scheduled jobs
print &ui_subheading($text{'dirstatus_sched'});
if (@$sched) {
	print &ui_columns_start([ $text{'dirstatus_name'},
				  $text{'dirstatus_level'},
				  $text{'dirstatus_type'},
				  $text{'dirstatus_date'},
				  $text{'dirstatus_volume'} ], "100%");
	foreach $j (@$sched) {
		print &ui_columns_row([
			&joblink($j->{'name'}),
			$j->{'level'},
			$j->{'type'},
			$j->{'date'},
			$j->{'volume'} ]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'dirstatus_schednone'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

