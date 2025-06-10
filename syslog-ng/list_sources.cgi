#!/usr/local/bin/perl
# Show a list of log sources

require './syslog-ng-lib.pl';
&ui_print_header(undef, $text{'sources_title'}, "", "sources");

$conf = &get_config();
@sources = &find("source", $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit_source.cgi?new=1",$text{'sources_add'}) );
if (@sources) {
	@tds = ( "width=5" );
	print &ui_form_start("delete_sources.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'sources_source'},
				  $text{'sources_desc'},
				  ], undef, 0, \@tds);
	foreach $f (@sources) {
		$desc = &nice_source_desc($f);
		print &ui_checked_columns_row([
			&ui_link("edit_source.cgi?name=$f->{'value'}",$f->{'value'}),
			$desc || "<i>$text{'sources_none2'}</i>",
			], \@tds, "d", $f->{'value'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'sources_delete'} ] ]);
	}
else {
	print "<b>$text{'sources_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("", $text{'index_return'});

