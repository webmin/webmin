#!/usr/local/bin/perl
# List all email templates

require './status-lib.pl';
$access{'edit'} || &error($text{'tmpls_ecannot'});
&ui_print_header(undef, $text{'tmpls_title'}, "");

@tmpls = &list_templates();
@links = ( &ui_link("edit_tmpl.cgi?new=1",$text{'tmpls_add'}) );
if (@tmpls) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_tmpls.cgi", "post");
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start(
	    [ "", $text{'tmpls_desc'}, $text{'tmpls_email'} ], 100, 0, \@tds);
	foreach $tmpl (@tmpls) {
		$msg = $tmpl->{'email'};
		$msg = substr($msg, 0, 80)." ..." if (length($msg) > 80);
		print &ui_checked_columns_row(
			[ &ui_link("edit_tmpl.cgi?id=$tmpl->{'id'}","$tmpl->{'desc'}"), &html_escape($msg) ],
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

