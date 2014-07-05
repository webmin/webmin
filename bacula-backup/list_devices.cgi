#!/usr/local/bin/perl
# Show a list of all backup devices

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'devices_title'}, "", "devices");

$conf = &get_storage_config();
@devices = &find("Device", $conf);
&sort_by_name(\@devices);
if (@devices) {
	print &ui_form_start("delete_devices.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_device.cgi?new=1",$text{'devices_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=40%", "width=30%" );
	print &ui_columns_start([ "", $text{'devices_name'},
				  $text{'devices_device'},
				  $text{'devices_type'} ], "100%", 0, \@tds);
	foreach $f (@devices) {
		$name = &find_value("Name", $f->{'members'});
		$device = &find_value("Archive Device", $f->{'members'});
		$type = &find_value("Media Type", $f->{'members'});
		print &ui_checked_columns_row([
			&ui_link("edit_device.cgi?name=".&urlize($name), $name),
			$device,
			$type,
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'devices_delete'} ] ]);
	}
else {
	print "<b>$text{'devices_none'}</b><p>\n";
	print &ui_link("edit_device.cgi?new=1", $text{'devices_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

