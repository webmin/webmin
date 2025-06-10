#!/usr/local/bin/perl
# Show all editable PHP configuration files

require './phpini-lib.pl';

# Get install button
my $install_button = &show_php_install_button();

# Do we have PHP installed?
my @pkgs = &list_php_base_packages();
if (!@pkgs && $install_button) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage($text{'pkgs_none2'}."<br>".$install_button);
	}

# Get editable files
@files = &list_php_configs();
if (!@files) {
	# User doesn't have access to any
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage($text{'index_eaccess'}."<br>".
			  $install_button);
	}
@files = grep { -r $_->[0] } @files;
if (!@files) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	if ($access{'noconfig'}) {
		&ui_print_endpage($text{'index_efiles'}."<br>".
				  $install_button);
		}
	else {
		&ui_print_endpage(&text('index_efiles2',
					"../config.cgi?$module_name")."<br>".
				  $install_button);
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
				&urlize($f->[0])."'>$text{'index_medit'}</a>" );
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
		print "$text{'index_anyfile'}&nbsp; \n";
		print &ui_textbox("file", undef, 40)." ".
		      &file_chooser_button("file")." ".
		      &ui_submit($text{'index_medit'})."\n";
		print &ui_form_end();
		}

	# Show button to install PHP versions
	print &show_php_install_button();

	&ui_print_footer("/", $text{'index'});
	}

# Print PHP install button if available
# Returns a button to install new PHP versions
sub show_php_install_button
{
&load_theme_library();
my $rv = '';
if ($access{'global'} && &foreign_available("software")) {
	$rv .= &ui_hr();
	$rv .= &ui_buttons_start();
	$rv .= &ui_buttons_row("list_pkgs.cgi",
		$text{'index_pkgs'},
		$text{'index_pkgsdesc'});
	$rv .= &ui_buttons_end();
	}
return $rv;
}
