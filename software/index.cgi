#!/usr/local/bin/perl
# index.cgi
# Lists all installed packages

require './software-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link(defined(&package_help) ? ( &package_help() ) : ( ),
			  "man", "doc"));

# Validate the package and update systems
$err = !defined(&check_package_system) ? $text{'index_echeckpackage'}
				       : &check_package_system();
if ($err) {
	&ui_print_endpage(&text('index_epackagecheck', $err,
				"../config.cgi?$module_name"));
	}
$err = !defined(&check_update_system) ? $text{'index_echeckupdate'}
				      : &check_update_system();
if ($err) {
	&ui_print_endpage(&text('index_eupdatecheck', $err,
				"../config.cgi?$module_name"));
	}

# Show package search and list forms
print &ui_subheading($text{'index_installed'});
print "<table width=100%><tr>\n";
print &ui_form_start("search.cgi");
print "<td>",&ui_submit($text{'index_search'}),"\n";
print &ui_textbox("search", undef, 40),"</td>\n";
print &ui_hidden("goto", 1),&ui_form_end();

print &ui_form_start("tree.cgi");
print "<td align=right>",&ui_submit($text{'index_tree'}),"</td>\n";
print &ui_form_end();
print "</tr></table>\n";

# Show form to install a new package
print &ui_hr();
print &ui_subheading($text{'index_install'});
print &text('index_installmsg', &package_system()),"<p>\n";

@opts = ( );
if (!$no_package_install) {
	push(@opts, [ 0, $text{'index_local'},
		      &ui_textbox("local", undef, 50)."\n".
		      &file_chooser_button("local", 0, 2) ]);
	push(@opts, [ 1, $text{'index_uploaded'},
		      &ui_upload("upload", 50) ]);
	push(@opts, [ 2, $text{'index_ftp'},
		      &ui_textbox("url", undef, 50)."\n".
		      ($has_search_system ? &capture_function_output(
						\&search_system_input) : "") ]);
	}
if ($has_update_system) {
	push(@opts, [ 3, $text{$update_system.'_input'},
	      &ui_textbox("update", undef, 30)."\n".
	      &update_system_button("update", $text{$update_system.'_find'}).
	      (defined(&show_update_system_opts) &&
               ($opts = &show_update_system_opts()) ? "<br>".$opts : "") ]);
	}
if (@opts) {
	$upid = time().$$;
	print &ui_form_start("install_pack.cgi?id=$upid", "form-data", undef,
			     &read_parse_mime_javascript($upid, [ "upload" ])),"\n";
	if (@opts > 1) {
		print &ui_radio_table("source", $opts[0]->[0], \@opts);
		}
	else {
		print "<b>",$opts[0]->[1],"</b> ",$opts[0]->[2],"<p>\n";
		print &ui_hidden("source", $opts[0]->[0]);
		}
	print &ui_submit($text{'index_installok'}),"\n";
	print &ui_form_end();
	}

# Show search form by file, if supported by package system
if (!$no_package_filesearch) {
	print &ui_hr();
	print &ui_subheading($text{'index_ident'});
	print &text('index_identmsg', &package_system()),"<p>\n";
	print &ui_form_start("file_info.cgi");
	print &ui_submit($text{'index_identok'}),"\n";
	print &ui_textbox("file", undef, 50),"\n",
	      &file_chooser_button("file", 0, 3);
	print &ui_form_end();
	}

if ($has_update_system && defined(&update_system_form)) {
	print &ui_hr();
	&update_system_form();
	}

&ui_print_footer("/", $text{'index'});

