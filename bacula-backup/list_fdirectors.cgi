#!/usr/local/bin/perl
# Show a list of all directors known to a file daemon

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'fdirectors_title'}, "", "fdirectors");

$conf = &get_file_config();
@fdirectors = &find("Director", $conf);
&sort_by_name(\@fdirectors);
if (@fdirectors) {
	print &ui_form_start("delete_fdirectors.cgi", "post");
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print &ui_link("edit_fdirector.cgi?new=1", $text{'fdirectors_add'}),"<br>\n";
	@tds = ( "width=5", "width=30%", "width=70%" );
	print &ui_columns_start([ "", $text{'fdirectors_name'},
				  $text{'fdirectors_pass'} ], "100%", 0, \@tds);
	foreach $f (@fdirectors) {
		$name = &find_value("Name", $f->{'members'});
		$pass = &find_value("Password", $f->{'members'});
		print &ui_columns_row([
			&ui_checkbox("d", $name),
			&ui_link("edit_fdirector.cgi?name=".&urlize($name),
				 $name),
			$pass,
			], \@tds);
		}
	print &ui_columns_end();
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print &ui_link("edit_fdirector.cgi?new=1", $text{'fdirectors_add'}),"<br>\n";
	print &ui_form_end([ [ "delete", $text{'fdirectors_delete'} ] ]);
	}
else {
	print "<b>$text{'fdirectors_none'}</b><p>\n";
	print &ui_link("edit_fdirector.cgi?new=1", $text{'fdirectors_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

