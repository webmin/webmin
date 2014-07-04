#!/usr/local/bin/perl
# Show a list of all backup clients

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'clients_title'}, "", "clients");

$conf = &get_director_config();
@clients = grep { !&is_oc_object($_) } &find("Client", $conf);
&sort_by_name(\@clients);
if (@clients) {
	print &ui_form_start("delete_clients.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_client.cgi?new=1",$text{'clients_add'}) );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=40%", "width=30%" );
	print &ui_columns_start([ "", $text{'clients_name'},
				  $text{'clients_address'},
				  $text{'clients_catalog'} ], "100%", 0, \@tds);
	foreach $f (@clients) {
		$name = &find_value("Name", $f->{'members'});
		$addr = &find_value("Address", $f->{'members'});
		$cat = &find_value("Catalog", $f->{'members'});
		print &ui_checked_columns_row([
			&ui_link("edit_client.cgi?name=".&urlize($name), $name),
			$addr,
			$cat,
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'clients_delete'} ] ]);
	}
else {
	print "<b>$text{'clients_none'}</b><p>\n";
	print &ui_link("edit_client.cgi?new=1",$text{'clients_add'})."<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

