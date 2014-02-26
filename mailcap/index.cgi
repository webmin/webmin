#!/usr/local/bin/perl
# Show current mailcap entries

require './mailcap-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

@mailcap = &list_mailcap();
if (@mailcap) {
	print &ui_form_start("delete.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit.cgi?new=1", $text{'index_add'}) );
	print &ui_links_row(\@links);

	@tds = ( "width=5" );
	print &ui_columns_start([
		"",
		$text{'index_type'},
		$text{'index_program'},
		$text{'index_cmt'},
		$text{'index_enabled'},
		], 100, 0, \@tds);
	foreach $m (@mailcap) {
		print &ui_checked_columns_row([
			&ui_link("edit.cgi?index=".$m->{'index'}, $m->{'type'}),
			$m->{'program'},
			$m->{'cmt'} || $m->{'args'}->{'description'},
			$m->{'enabled'} ? $text{'yes'} :
			    "<font color=#ff0000>$text{'no'}</font>",
			], \@tds, "d", $m->{'index'});
		}
	print &ui_columns_end();

	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     undef,
			     [ "disable", $text{'index_disable'} ],
			     [ "enable", $text{'index_enable'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_link("edit.cgi?new=1", $text{'index_add'});
    print "<p>\n";
	}

&ui_print_footer("/", $text{'index'});
