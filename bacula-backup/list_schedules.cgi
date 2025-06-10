#!/usr/local/bin/perl
# Show a list of all backup schedules

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'schedules_title'}, "", "schedules");

$conf = &get_director_config();
@schedules = &find("Schedule", $conf);
&sort_by_name(\@schedules);
if (@schedules) {
	print &ui_form_start("delete_schedules.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_schedule.cgi?new=1",$text{'schedules_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=70%" );
	print &ui_columns_start([ "", $text{'schedules_name'},
				  $text{'schedules_sched'} ], "100%", 0, \@tds);
	foreach $f (@schedules) {
		$name = &find_value("Name", $f->{'members'});
		@runs = &find_value("Run", $f->{'members'});
		if (@runs > 2) {
			@runs = ( @runs[0..1], "..." );
			}
		print &ui_checked_columns_row([
			&ui_link("edit_schedule.cgi?name=".&urlize($name),$name),
			join(" , ", @runs),
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'schedules_delete'} ] ]);
	}
else {
	print "<b>$text{'schedules_none'}</b><p>\n";
	print &ui_link("edit_schedule.cgi?new=1",$text{'schedules_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

