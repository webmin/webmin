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
print "<form action=install_pack.cgi method=post ",
      "enctype=multipart/form-data>\n";
print "<input type=radio name=source value=0 checked> $text{'index_local'}\n";
print "<input name=local size=50>\n";
print &file_chooser_button("local", 0, 2); print "<br>\n";
print "<input type=radio name=source value=1> $text{'index_uploaded'}\n";
print "<input type=file name=upload size=20><br>\n";
print "<input type=radio name=source value=2> $text{'index_ftp'}\n";
print "<input name=url size=50>\n";
print &search_system_input() if ($has_search_system);
print "<br>\n";
if ($has_update_system) {
	print "<input type=radio name=source value=3>\n";
	print $text{$update_system.'_input'},"\n";
	print &ui_textbox("update", undef, 30),"\n";
	print &update_system_button("update", $text{$update_system.'_find'});
	if (defined(&show_update_system_opts) &&
	    ($opts = &show_update_system_opts())) {
		print "<br>",("&nbsp;" x 5),$opts,"\n";
		}
	print "<br>\n";
	}
print "<input type=submit value=\"$text{'index_installok'}\">\n";
print "</form>\n";

print "<hr>\n";
print &ui_subheading($text{'index_ident'});
print &text('index_identmsg', &package_system()),"<p>\n";
print "<form action=file_info.cgi>\n";
print "<input type=submit value=\"$text{'index_identok'}\">\n";
print "<input name=file size=30>\n";
print &file_chooser_button("file", 0, 3);
print "</form>\n";

if ($has_update_system && defined(&update_system_form)) {
	print "<hr>\n";
	&update_system_form();
	}

&ui_print_footer("/", $text{'index'});

