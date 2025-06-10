#!/usr/local/bin/perl
# Show a list of all directors known to the storage daemon

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'sdirectors_title'}, "", "sdirectors");

$conf = &get_storage_config();
@sdirectors = &find("Director", $conf);
&sort_by_name(\@sdirectors);
if (@sdirectors) {
	print &ui_form_start("delete_sdirectors.cgi", "post");
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print &ui_link("edit_sdirector.cgi?new=1",$text{'sdirectors_add'}),"<br>\n";
	@tds = ( "width=5", "width=30%", "width=70%" );
	print &ui_columns_start([ "", $text{'sdirectors_name'},
				  $text{'sdirectors_pass'} ], "100%", 0, \@tds);
	foreach $f (@sdirectors) {
		$name = &find_value("Name", $f->{'members'});
		$pass = &find_value("Password", $f->{'members'});
		print &ui_columns_row([
			&ui_checkbox("d", $name),
			&ui_link("edit_sdirector.cgi?name=".&urlize($name),
				 $name),
			$pass,
			], \@tds);
		}
	print &ui_columns_end();
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print &ui_link("edit_sdirector.cgi?new=1", $text{'sdirectors_add'}),"<br>\n";
	print &ui_form_end([ [ "delete", $text{'sdirectors_delete'} ] ]);
	}
else {
	print "<b>$text{'sdirectors_none'}</b><p>\n";
	print &ui_link("edit_sdirector.cgi?new=1",$text{'sdirectors_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

