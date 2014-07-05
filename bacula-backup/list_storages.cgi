#!/usr/local/bin/perl
# Show a list of all backup storages

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'storages_title'}, "", "storages");

$conf = &get_director_config();
@storages = &find("Storage", $conf);
&sort_by_name(\@storages);
if (@storages) {
	print &ui_form_start("delete_storages.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_storage.cgi?new=1",$text{'storages_add'}),
		 );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=20%", "width=30%", "width=20%" );
	print &ui_columns_start([ "", $text{'storages_name'},
				  $text{'storages_address'},
				  $text{'storages_device'},
				  $text{'storages_type'} ], "100%", 0, \@tds);
	foreach $f (@storages) {
		$name = &find_value("Name", $f->{'members'});
		$addr = &find_value("Address", $f->{'members'});
		$device = &find_value("Device", $f->{'members'});
		$type = &find_value("Media Type", $f->{'members'});
		print &ui_checked_columns_row([
			&ui_link("edit_storage.cgi?name=".&urlize($name),$name),
			$addr,
			$device,
			$type,
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'storages_delete'} ] ]);
	}
else {
	print "<b>$text{'storages_none'}</b><p>\n";
	print &ui_link("edit_storage.cgi?new=1",$text{'storages_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

