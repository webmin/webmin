#!/usr/local/bin/perl
# index.cgi
# Display a list of exports

require './bsdexports-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Check if installed
my $err = &check_exports();
if ($err) {
	print "<b>",&text('index_echeck', $err),"</b><p>\n";
	&ui_print_footer("/", $text{'index'});
	return;
	}

@exp = &list_exports();
if (@exp) {
	print &ui_form_start("delete_exports.cgi", "post");
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print "<a href=edit_export.cgi>$text{'index_add'}</a> <br>\n";

	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'index_dirs'},
				  $text{'index_clients'} ], 100, 0, \@tds);
	foreach $e (@exp) {
		local @cols;
		push(@cols, "<a href=\"edit_export.cgi?index=$e->{'index'}\">".
			    join(" ", @{$e->{'dirs'}})."</a>");
		if ($e->{'network'}) {
			push(@cols, "$e->{'network'} / $e->{'mask'}");
			}
		elsif (!$e->{'hosts'}) {
			push(@cols, $text{'index_everyone'});
			}
		else {
			push(@cols, join("&nbsp;|&nbsp;", @{$e->{'hosts'}}));
			}
		print &ui_checked_columns_row(\@cols, \@tds, "d",
					      $e->{'index'});
		}
	print &ui_columns_end();

	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print "<a href=edit_export.cgi>$text{'index_add'}</a> <br>\n";
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	print "<a href=edit_export.cgi>$text{'index_add'}</a> <p>\n";
	}

print &ui_hr();

print &ui_buttons_start();
print &ui_buttons_row("restart_mountd.cgi",
		      $text{'index_apply'},
		      $text{'index_applydesc'});
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});


