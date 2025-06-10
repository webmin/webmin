#!/usr/local/bin/perl
# Show a list of backup jobs that use node groups

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'gjobs_title'}, "", "gjobs");

$conf = &get_director_config();
@jobs = grep { &is_oc_object($_) } &find("JobDefs", $conf);
&sort_by_name(\@jobs);
if (@jobs) {
	print &ui_form_start("delete_gjobs.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_gjob.cgi?new=1",$text{'gjobs_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=40%", "width=20%", "width=20%",
		 "width=20%" );
	print &ui_columns_start([ "", $text{'jobs_name'},
				  $text{'jobs_type'},
				  $text{'gjobs_client'},
				  $text{'jobs_fileset'} ], "100%", 0, \@tds);
	foreach $f (@jobs) {
		$name = &find_value("Name", $f->{'members'});
		$name = &is_oc_object($name);
		$type = &find_value("Type", $f->{'members'});
		$client = &find_value("Client", $f->{'members'});
		$client = &is_oc_object($client);
		$fileset = &find_value("FileSet", $f->{'members'});
		print &ui_checked_columns_row([
			&ui_link("edit_gjob.cgi?name=".&urlize($name), $name),
			$type || "<i>$text{'default'}</i>",
			$client || "<i>$text{'default'}</i>",
			$fileset || "<i>$text{'default'}</i>",
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'gjobs_delete'} ] ]);
	}
else {
	print "<b>$text{'jobs_none'}</b><p>\n";
	print &ui_link("edit_gjob.cgi?new=1",$text{'gjobs_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

