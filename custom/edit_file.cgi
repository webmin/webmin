#!/usr/local/bin/perl
# edit_file.cgi
# Display a file editor and its options

require './custom-lib.pl';
&ReadParse();

$access{'edit'} || &error($text{'file_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'fcreate_title'}, "", "fcreate");
	}
else {
	&ui_print_header(undef, $text{'fedit_title'}, "", "fedit");
	@cmds = &list_commands();
	$edit = $cmds[$in{'idx'}];
	}

print &ui_form_start("save_file.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'file_details'}, "width=100%", 4);

if (!$in{'new'}) {
	print "<tr> <td valign=top><b>",&hlink($text{'file_id'}, "fileid"),
	      "</b></td>\n";
	print "<td><tt>$edit->{'id'}</tt></td> </tr>\n";
	}

print "<tr> <td valign=top><b>",&hlink($text{'file_desc'}, "fdesc"),
      "</b></td>\n";
print "<td><input name=desc size=50 value='",
	&html_escape($edit->{'desc'}),"'><br>\n";
print "<textarea name=html rows=2 cols=50>",$edit->{'html'},
      "</textarea></td> </tr>\n";

print "<tr> <td><b>",&hlink($text{'file_edit'}, "file"),"</b></td>\n";
print "<td><input name=edit size=50 value='$edit->{'edit'}'> ",
      &file_chooser_button("edit", 0),"</td> </tr>\n";

print "<tr> <td></td>\n";
printf "<td><input type=checkbox name=envs value=1 %s> %s</td> </tr>\n",
	$edit->{'envs'} ? "checked" : "", $text{'file_envs'};

print "<tr> <td><b>",&hlink($text{'file_owner'}, "owner"),"</b></td>\n";
printf "<td><input type=radio name=owner_def value=1 %s> %s\n",
	$edit->{'user'} ? '' : 'checked', $text{'file_leave'};
printf "<input type=radio name=owner_def value=0 %s> %s\n",
	$edit->{'user'} ? 'checked' : '', $text{'file_user'};
printf "<input name=user size=8 value='%s'> %s\n",
	$edit->{'user'}, $text{'file_group'};
printf "<input name=group size=8 value='%s'></td> </tr>\n",
	$edit->{'group'};

print "<tr> <td><b>",&hlink($text{'file_perms'}, "perms"),"</b></td>\n";
printf "<td><input type=radio name=perms_def value=1 %s> %s\n",
	$edit->{'perms'} ? '' : 'checked', $text{'file_leave'};
printf "<input type=radio name=perms_def value=0 %s> %s\n",
	$edit->{'perms'} ? 'checked' : '', $text{'file_set'};
printf "<input name=perms size=3 value='%s'></td> </tr>\n",
	$edit->{'perms'};

print "<tr> <td><b>",&hlink($text{'file_before'}, "before"),"</b></td>\n";
print "<td><input name=before size=60 value='",
	&html_escape($edit->{'before'}),"'></td> </tr>\n";

print "<tr> <td><b>",&hlink($text{'file_after'}, "after"),"</b></td>\n";
print "<td><input name=after size=60 value='",
	&html_escape($edit->{'after'}),"'></td> </tr>\n";

print "<tr> <td><b>",&hlink($text{'edit_order'}, "order"),"</b></td>\n";
printf "<td><input type=radio name=order_def value=1 %s> %s\n",
	$edit->{'order'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=order_def value=0 %s>\n",
	$edit->{'order'} ? "checked" : "";
printf "<input name=order size=6 value='%s'></td> </tr>\n",
	$edit->{'order'} ? $edit->{'order'} : '';

print "<tr> <td><b>",&hlink($text{'edit_usermin'},"usermin"),"</b></td>\n";
printf "<td><input type=radio name=usermin value=1 %s> %s\n",
	$edit->{'usermin'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=usermin value=0 %s> %s</td> </tr>\n",
	$edit->{'usermin'} ? "" : "checked", $text{'no'};

print "</table></td></tr></table><p>\n";

&show_params_inputs($edit, 1, 1);

print "<table width=100%><tr>\n";
print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
if (!$in{'new'}) {
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

