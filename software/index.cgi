#!/usr/local/bin/perl
# index.cgi
# Lists all installed packages

require './software-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link(defined(&package_help) ? ( &package_help() ) : ( ),
			  "man", "doc"));

# Show package search and list forms
print &ui_subheading($text{'index_installed'});
print "<table width=100%><tr><form action=search.cgi>\n";
print "<td><input type=submit value=\"$text{'index_search'}\">\n";
print "<input name=search size=30></td>\n";
print "<input type=hidden name=goto value=1>\n";
print "</form>\n";

print "<form action=tree.cgi>\n";
print "<td align=right><input type=submit value='$text{'index_tree'}'></td>\n";
print "</form></tr></table>\n";

# Show form to install a new package
print "<hr>\n";
print &ui_subheading($text{'index_install'});
print &text('index_installmsg', &package_system()),"<p>\n";

$upid = time().$$;
print &ui_form_start("install_pack.cgi?id=$upid", "form-data", undef,
		     &read_parse_mime_javascript($upid, [ "upload" ])),"\n";
print &ui_oneradio("source", 0, $text{'index_local'}, 1),"\n",
      &ui_textbox("local", undef, 50),"\n",
      &file_chooser_button("local", 0, 2),"<br>\n";

print &ui_oneradio("source", 1, $text{'index_uploaded'}, 0),"\n",
      &ui_upload("upload", 20),"<br>\n";

print &ui_oneradio("source", 2, $text{'index_ftp'}, 0),"\n",
      &ui_textbox("url", undef, 50),"\n";
print &search_system_input() if ($has_search_system);
print "<br>\n";

if ($has_update_system) {
	print &ui_oneradio("source", 3, $text{$update_system.'_input'}, 0),"\n",
	      &ui_textbox("update", undef, 30),"\n",
	      &update_system_button("update", $text{$update_system.'_find'});
	if (defined(&show_update_system_opts) &&
	    ($opts = &show_update_system_opts())) {
		print "<br>",("&nbsp;" x 5),$opts,"\n";
		}
	print "<br>\n";
	}
print &ui_submit($text{'index_installok'}),"\n";
print &ui_form_end();

# Show search form by file, if supported by package system
if (!$no_package_filesearch) {
	print "<hr>\n";
	print &ui_subheading($text{'index_ident'});
	print &text('index_identmsg', &package_system()),"<p>\n";
	print "<form action=file_info.cgi>\n";
	print "<input type=submit value=\"$text{'index_identok'}\">\n";
	print "<input name=file size=30>\n";
	print &file_chooser_button("file", 0, 3);
	print "</form>\n";
	}

if ($has_update_system && defined(&update_system_form)) {
	print "<hr>\n";
	&update_system_form();
	}

&ui_print_footer("/", $text{'index'});

