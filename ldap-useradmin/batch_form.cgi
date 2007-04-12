#!/usr/local/bin/perl
# batch_form.cgi
# Display a form for doing batch creation, updates or deletion from a text file

require './ldap-useradmin-lib.pl';
$access{'batch'} || &error($text{'batch_ecannot'});
&ui_print_header(undef, $text{'batch_title'}, "");

$ldap = &ldap_connect();
$schema = $ldap->schema();
$pft = $schema->attribute("shadowLastChange") ? 2 : 0;

print "$text{'batch_desc'}\n";
print "<p><tt>",$text{'batch_desc'.$pft},"</tt><p>\n";
print "$text{'batch_descafter'}<br>\n";
print "$text{'batch_descafter2'}<br>\n";
print "$text{'batch_descafter3'}<br>\n";

print "<form action=batch_exec.cgi method=post enctype=multipart/form-data>\n";
print "<table>\n";

print "<tr> <td valign=top><b>$text{'batch_source'}</b></td> <td>\n";
print "<input type=radio name=source value=0 checked> ",
      "$text{'batch_source0'} <input type=file name=file><br>\n";
print "<input type=radio name=source value=1> ",
      "$text{'batch_source1'} <input name=local size=30> ",
      &file_chooser_button("local"),"<br>\n";
print "<input type=radio name=source value=2> ",
      "$text{'batch_source2'}<br><textarea name=text rows=5 cols=50></textarea>",
      "</td> </tr>\n";

print "<tr> <td><b>$text{'batch_others'}</b></td>\n";
print "<td>",&ui_yesno_radio("others", $mconfig{'default_other'} ? 1 : 0),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'batch_batch'}</b></td>\n";
print "<td>",&ui_yesno_radio("batch", 1),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_makehome'}</b></td>\n";
print "<td>",&ui_yesno_radio("makehome", 1),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_copy'}</b></td>\n";
print "<td>",&ui_yesno_radio("copy", 1),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_movehome'}</b></td>\n";
print "<td>",&ui_yesno_radio("movehome", 1),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_chuid'}</b></td>\n";
print "<td>",&ui_radio("chuid", 1, [ [ 0, $text{'no'} ],
			     [ 1, $text{'home'} ],
			     [ 2, $text{'uedit_allfiles'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_chgid'}</b></td>\n";
print "<td>",&ui_radio("chgid", 1, [ [ 0, $text{'no'} ],
			     [ 1, $text{'home'} ],
			     [ 2, $text{'uedit_allfiles'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_delhome'}</b></td>\n";
print "<td>",&ui_yesno_radio("delhome", 1),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_crypt'}</b></td>\n";
print "<td>",&ui_yesno_radio("crypt", 0),"</td> </tr>\n";

print "<tr> <td><b>$text{'batch_samba'}</b></td>\n";
print "<td>",&ui_yesno_radio("samba", $config{'samba_def'} ? 1 : 0),"</td> </tr>\n";

print "<tr> <td><input type=submit value=\"$text{'batch_upload'}\"></td> </tr>\n";
print "</table></form>\n";

&ui_print_footer("", $text{'index_return'});

