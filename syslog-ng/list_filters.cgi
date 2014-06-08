#!/usr/local/bin/perl
# Show a list of log files

require './syslog-ng-lib.pl';
&ui_print_header(undef, $text{'filters_title'}, "", "filters");

$conf = &get_config();
@filters = &find("filter", $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit_filter.cgi?new=1",$text{'filters_add'}) );
if (@filters) {
	@tds = ( "width=5" );
	print &ui_form_start("delete_filters.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'filters_name'},
				  $text{'filters_desc'},
				  ], undef, 0, \@tds);
	foreach $f (@filters) {
		$desc = &nice_filter_desc($f);
		if ($desc =~ /^(.*?)([a-z])(.*)/) {
			  $desc = $1.ucfirst($2).$3;
			  }
		print &ui_checked_columns_row([
			"<a href='edit_filter.cgi?name=".
			  &urlize($f->{'value'})."'>$f->{'value'}</a>",
			$desc,
			], \@tds, "d", $f->{'value'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'filters_delete'} ] ]);
	}
else {
	print "<b>$text{'filters_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("", $text{'index_return'});

