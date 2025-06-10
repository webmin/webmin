#!/usr/local/bin/perl
# Show a list of log targets

require './syslog-ng-lib.pl';
&ui_print_header(undef, $text{'logs_title'}, "", "logs");

$conf = &get_config();
@logs = &find("log", $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit_log.cgi?new=1",$text{'logs_add'}) );
if (@logs) {
	@tds = ( "width=5" );
	print &ui_form_start("delete_logs.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'logs_source'},
				  $text{'logs_filter'},
				  $text{'logs_destination'},
				  ], undef, 0, \@tds);
	foreach $f (@logs) {
		$source = join(", ", &find_value("source", $f->{'members'}));
		$filter = join(", ", &find_value("filter", $f->{'members'}));
		$dest = join(", ", &find_value("destination", $f->{'members'}));
		print &ui_checked_columns_row([
			&ui_link("edit_log.cgi?idx=$f->{'index'}",$source),
			$filter || "<i>$text{'logs_none'}</i>",
			$dest || "<i>$text{'logs_none'}</i>",
			], \@tds, "d", $f->{'index'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'logs_delete'} ] ]);
	}
else {
	print "<b>$text{'logs_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("", $text{'index_return'});

