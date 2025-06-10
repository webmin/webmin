#!/usr/local/bin/perl
# Show a list of all backup pools

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'pools_title'}, "", "pools");

$conf = &get_director_config();
@pools = &find("Pool", $conf);
&sort_by_name(\@pools);
if (@pools) {
	print &ui_form_start("delete_pools.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_pool.cgi?new=1",$text{'pools_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=40%", "width=30%" );
	print &ui_columns_start([ "", $text{'pools_name'},
				  $text{'pools_type'},
				  $text{'pools_reten'} ], "100%", 0, \@tds);
	foreach $f (@pools) {
		$name = &find_value("Name", $f->{'members'});
		$type = &find_value("Pool Type", $f->{'members'});
		$reten = &find_value("Volume Retention", $f->{'members'});
		print &ui_checked_columns_row([
			&ui_link("edit_pool.cgi?name=".&urlize($name), $name),
			$type,
			$reten,
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'pools_delete'} ] ]);
	}
else {
	print "<b>$text{'pools_none'}</b><p>\n";
	print &ui_link("edit_pool.cgi?new=1",$text{'pools_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

