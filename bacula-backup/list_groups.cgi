#!/usr/local/bin/perl
# Show all groups that are actually templates for OC-Host node groups

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'groups_title'}, "", "groups");

$conf = &get_director_config();
@groups = &find("Client", $conf);
@groups = grep { $name = &find_value("Name", $_->{'members'});
		 $name =~ /^ocgroup_/ } @groups;
&sort_by_name(\@groups);
if (@groups) {
	print &ui_form_start("delete_groups.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d") );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=40%", "width=30%" );
	print &ui_columns_start([ "", $text{'groups_name'},
				  $text{'groups_port'},
				  $text{'groups_catalog'} ], "100%", 0, \@tds);
	foreach $f (@groups) {
		$name = &find_value("Name", $f->{'members'});
		$name =~ s/^ocgroup_//g;
		$port = &find_value("FDPort", $f->{'members'});
		$cat = &find_value("Catalog", $f->{'members'});
		$done{$name}++;
		print &ui_checked_columns_row([
			&ui_link("edit_group.cgi?name=".&urlize($name), $name),
			$port,
			$cat,
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'groups_delete'} ] ]);
	}
else {
	print "<b>$text{'groups_none'}</b><p>\n";
	}

@ng = &list_node_groups();
@canng = grep { !$done{$_->{'name'}} } @ng;
if (@canng) {
	# Show adding form
	print &ui_form_start("edit_group.cgi");
	print "<b>$text{'groups_add'}</b>\n";
	print &ui_select("new", undef,
		[ map { [ $_->{'name'}, &text('groups_info', $_->{'name'}, scalar(@{$_->{'members'}})) ] } @canng ]);
	print &ui_submit($text{'groups_ok'});
	print &ui_form_end();
	}
elsif (@ng) {
	print "<b>$text{'groups_already'}</b><p>\n";
	}
else {
	print "<b>$text{'groups_noadd'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

