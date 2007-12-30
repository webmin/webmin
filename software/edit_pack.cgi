#!/usr/local/bin/perl
# edit_pack.cgi
# Displays the details of an existing package, with links to uninstall and
# other options

require './software-lib.pl';
&ReadParse();
@pinfo = &package_info($in{'package'}, $in{'version'});
$pinfo[0] || &error($text{'edit_egone'});
&ui_print_header(undef, $text{'edit_title'}, "", "edit_pack");

@pinfo = &show_package_info($in{'package'}, $in{'version'}, 1);
print "<table><tr>\n";

# Show button to list files, if supported
if (!$pinfo[8]) {
	print &ui_form_start("list_pack.cgi");
	print &ui_hidden("package", $pinfo[0]);
	print &ui_hidden("version", $pinfo[4]);
	print &ui_hidden("search", $in{'search'});
	print "<td>",&ui_submit($text{'edit_list'}),"</td>\n";
	print &ui_form_end();
	}

# Show button to un-install (if possible)
if (!$pinfo[7]) {
	print &ui_form_start("delete_pack.cgi");
	print &ui_hidden("package", $pinfo[0]);
	print &ui_hidden("version", $pinfo[4]);
	print &ui_hidden("search", $in{'search'});
	print "<td>",&ui_submit($text{'edit_uninst'}),"</td>\n";
	print &ui_form_end();
	}

print "</tr></table>\n";

if ($in{'search'}) {
	&ui_print_footer("search.cgi?search=$in{'search'}", $text{'search_return'});
	}
else {
	&ui_print_footer("tree.cgi#$pinfo[1]", $text{'index_treturn'});
	}


