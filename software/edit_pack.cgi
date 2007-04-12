#!/usr/local/bin/perl
# edit_pack.cgi
# Displays the details of an existing package, with links to uninstall and
# other options

require './software-lib.pl';
&ReadParse();
@pinfo = &package_info($in{'package'}, $in{'version'});
$pinfo[0] || &error($text{'edit_egone'});
&ui_print_header(undef, $text{'edit_title'}, "", "edit_pack");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($pinfo[2]) {
	print "<tr> <td valign=top width=20%><b>$text{'edit_desc'}</b></td>\n";
	print "<td colspan=3 align=left><pre>",
	      &html_escape(&entities_to_ascii($pinfo[2])),
	      "</pre></td> </tr>\n";
	}

print "<tr> <td width=20%><b>$text{'edit_pack'}</b></td> <td>",
	&html_escape($pinfo[0]),"</td>\n";
print "<td width=20%><b>$text{'edit_class'}</b></td> <td>",
      $pinfo[1] ? &html_escape($pinfo[1]) : $text{'edit_none'},"</td> </tr>\n";

print "<tr> <td width=20%><b>$text{'edit_ver'}</b></td> <td>",
	&html_escape($pinfo[4]),"</td>\n";
print "<td width=20%><b>$text{'edit_vend'}</b></td> <td>",
	&html_escape($pinfo[5]),"</td> </tr>\n";

print "<tr> <td width=20%><b>$text{'edit_arch'}</b></td> <td>",
	&html_escape($pinfo[3]),"</td>\n";
print "<td width=20%><b>$text{'edit_inst'}</b></td> <td>",
	&html_escape($pinfo[6]),"</td> </tr>\n";
print "</table></td></tr></table><p>\n";

print "<table width=100%> <tr>\n";

# Show button to list files, if supported
if (!$pinfo[8]) {
	print "<form action=list_pack.cgi>\n";
	print "<input type=hidden name=package value=\"$pinfo[0]\">\n";
	print "<input type=hidden name=version value=\"$pinfo[4]\">\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<td align=left><input type=submit value=\"$text{'edit_list'}\"></td>\n";
	print "</form>\n";
	}

# Show button to un-install (if possible)
if (!$pinfo[7]) {
	print "<form action=delete_pack.cgi>\n";
	print "<input type=hidden name=package value=\"$pinfo[0]\">\n";
	print "<input type=hidden name=version value=\"$pinfo[4]\">\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<td align=right>\n";
	print "<input type=submit value=\"$text{'edit_uninst'}\"></td>\n";
	print "</form>\n";
	}

print "</tr> </table><p>\n";

if ($in{'search'}) {
	&ui_print_footer("search.cgi?search=$in{'search'}", $text{'search_return'});
	}
else {
	&ui_print_footer("tree.cgi#$pinfo[1]", $text{'index_treturn'});
	}


