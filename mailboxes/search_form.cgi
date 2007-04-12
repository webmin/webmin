#!/usr/local/bin/perl
# search_form.cgi
# Display a form for searching a mailbox

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});

@folders = &list_user_folders_sorted($in{'user'});
($folder) = grep { $_->{'index'} == $in{'folder'} } @folders;
&ui_print_header(undef, $text{'sform_title'}, "", undef, 0, 0, undef,
	&folder_link($in{'user'}, $folder));

print "<form action=mail_search.cgi>\n";
print "<input type=hidden name=user value='$in{'user'}'>\n";
print "<input type=hidden name=ofolder value='$in{'folder'}'>\n";
print "<input type=radio name=and value=1 checked> $text{'sform_and'}\n";
print "<input type=radio name=and value=0> $text{'sform_or'}<p>\n";

print "<table>\n";
#print "<tr> <td><b>$text{'sform_field'}</b></td> ",
#      "<td><b>$text{'sform_mode'}</b></td> ",
#      "<td><b>$text{'sform_for'}</b></td> </tr>\n";
for($i=0; $i<=9; $i++) {
	print "<tr>\n";
	print "<td>$text{'sform_where'}</td>\n";
	print "<td><select name=field_$i>\n";
	print "<option value=''>&nbsp;\n";
	foreach $f ('from', 'subject', 'to', 'cc', 'date', 'body', 'headers', 'size') {
		print "<option value=$f>",$text{"sform_$f"},"\n";
		}
	print "</select></td>\n";

	print "<td><select name=neg_$i>\n";
	print "<option value=0 checked>$text{'sform_neg0'}\n";
	print "<option value=1>$text{'sform_neg1'}\n";
	print "</select></td>\n";

	print "<td>$text{'sform_text'}</td>\n";
	print "<td><input name=what_$i size=30></td>\n";
	print "</tr>\n";
	}
print "</table><br>\n";

$extra = "<option value=-1>$text{'sform_all'}\n";
print "<input type=submit value='$text{'sform_ok'}'>\n";
print " $text{'sform_folder'} ",&folder_select(\@folders, $folder, "folder",
					       $extra);
print "</form>\n";

&ui_print_footer("list_mail.cgi?folder=$in{'folder'}&user=".
		  &urlize($in{'user'}), $text{'mail_return'},
		 "", $text{'index_return'});

