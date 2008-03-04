#!/usr/local/bin/perl
# List all email templates

require './status-lib.pl';
&ui_print_header(undef, $text{'tmpls_title'}, "");

@tmpls = &list_templates();
@links = ( "<a href='edit_tmpl.cgi?new=1'>$text{'tmpls_add'}</a>" );
if (@tmpls) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_tmpls.cgi", "post");
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([ "", $text{'tmpl_desc'}, $text{'tmpl_msg'} ],
				100, 0, \@tds);
	foreach $tmpl (@tmpls) {
		$msg = $tmpl->{'msg'};
		$msg = substr($msg, 0, 8)." ..." if (length($msg) > 80);
		print &ui_checked_columns_row(
			[ $tmpl->{'desc'}, &html_escape($msg) ],
		      	\@tds, "d", $tmpl->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'tmpls_delete'} ] ]);
	}
else {
	print "<b>$text{'tmpls_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});

