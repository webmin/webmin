#!/usr/local/bin/perl
# Show all editable PHP configuration files

require './phpini-lib.pl';

# Get editable files
@files = &list_php_configs();
if (!@files) {
	# User doesn't have access to any
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage($text{'index_eaccess'});
	}
@files = grep { -r $_->[0] } @files;
if (!@files) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	if ($access{'noconfig'}) {
		&ui_print_endpage($text{'index_efiles'});
		}
	else {
		&ui_print_endpage(&text('index_efiles2',
					"../config.cgi?$module_name"));
		}
	}

if (@files == 1 && !$access{'anyfile'} && $access{'noconfig'}) {
	# Just re-direct to the one file
	&redirect("list_ini.cgi?file=".&urlize($files[0]->[0]));
	}
else {
	# Show a table of config files
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

	@tds = ( undef, undef, "width=10% nowrap" );
	print &ui_columns_start([ $text{'index_file'},
				  $text{'index_desc'},
				  $text{'index_actions'} ],
				100, 0, \@tds);
	foreach $f (@files) {
		local @acts = ( "<a href='list_ini.cgi?file=".
				&urlize($f->[0])."'>$text{'index_edit'}</a>" );
		if ($access{'manual'}) {
			push(@acts, "<a href='edit_manual.cgi?file=".
			    &urlize($f->[0])."'>$text{'index_manual'}</a>");
			}
		print &ui_columns_row([
			"<tt>$f->[0]</tt>",
			$f->[1],
			join(" | ", @acts)
			], \@tds);
		}
	print &ui_columns_end();

	# Allow entering a file to edit
	if ($access{'anyfile'}) {
		print "<p>\n";
		print &ui_form_start("list_ini.cgi");
		print "<b>$text{'index_anyfile'}</b>\n";
		print &ui_textbox("file", undef, 40)." ".
		      &file_chooser_button("file")." ".
		      &ui_submit($text{'index_edit'})."\n";
		print &ui_form_end();
		}

	&ui_print_footer("/", $text{'index'});
	}

