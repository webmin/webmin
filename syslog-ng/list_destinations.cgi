#!/usr/local/bin/perl
# Show a list of log destinations

require './syslog-ng-lib.pl';
&ui_print_header(undef, $text{'destinations_title'}, "", "destinations");

$conf = &get_config();
@dests = &find("destination", $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit_destination.cgi?new=1",$text{'destinations_add'}),
	 );
if (@dests) {
	@tds = ( "width=5" );
	print &ui_form_start("delete_destinations.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'destinations_name'},
				  $text{'destinations_type'},
				  $text{'destinations_file'},
				  "", ], undef, 0, \@tds);
	foreach $d (@dests) {
		($type, $typeid) = &nice_destination_type($d);
		$file = &nice_destination_file($d);
		$realfile = &find_value("file", $d->{'members'});
		print &ui_checked_columns_row([
			"<a href='edit_destination.cgi?name=".
			  &urlize($d->{'value'})."'>$d->{'value'}</a>",
			$type || "???",
			$file || "???",
			$typeid == 0 && -f $realfile ?
			  "<a href='view_log.cgi?dest=".&urlize($d->{'value'}).
			  "'>$text{'destinations_view'}</a>" : "",
			], \@tds, "d", $d->{'value'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'destinations_delete'} ] ]);
	}
else {
	print "<b>$text{'destinations_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

# Show other module's logs
@others = &get_other_module_logs();
if (@others) {
	print &ui_hr();
	print &ui_columns_start([ $text{'destinations_desc'},
				  $text{'destinations_file'},
				  "" ]);
	foreach $o (@others) {
		print &ui_columns_row([
			$o->{'desc'},
			$o->{'file'} ? "<tt>$o->{'file'}</tt>"
				     : &text('destinations_cmd', $o->{'cmd'}),
			"<a href='view_log.cgi?oidx=$o->{'mindex'}".
			"&omod=$o->{'mod'}'>$text{'destinations_view'}</a>",
			]);
		}
	print &ui_columns_end();
	}

&ui_print_footer("", $text{'index_return'});

