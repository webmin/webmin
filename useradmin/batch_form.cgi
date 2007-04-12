#!/usr/local/bin/perl
# batch_form.cgi
# Display a form for doing batch creation, updates or deletion from a text file

require './user-lib.pl';
%access = &get_module_acl();
$access{'batch'} || &error($text{'batch_ecannot'});
&ui_print_header(undef, $text{'batch_title'}, "");

print "$text{'batch_desc'}\n";
$pft = &passfiles_type();
print "<p><tt>",$text{'batch_desc'.$pft},"</tt><p>\n";
print "$text{'batch_descafter'}<br>\n";
print "$text{'batch_descafter2'}\n";

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

if ($access{'cothers'} == 1 || $access{'mothers'} == 1 ||
    $access{'dothers'} == 1) {
	print "<tr> <td><b>$text{'batch_others'}</b></td>\n";
	printf "<td><input name=others type=radio value=1 %s> $text{'yes'}\n",
		$config{'default_other'} ? "checked" : "";
	printf "<input name=others type=radio value=0 %s> $text{'no'}</td> </tr>\n",
		$config{'default_other'} ? "" : "checked";
	}

print "<tr> <td><b>$text{'batch_batch'}</b></td>\n";
print "<td><input name=batch type=radio value=1> $text{'yes'}\n";
print "<input name=batch type=radio value=0 checked> $text{'no'}</td> </tr>\n";

if ($access{'makehome'}) {
	print "<tr> <td><b>$text{'batch_makehome'}</b></td>\n";
	print "<td><input name=makehome type=radio value=1 checked> $text{'yes'}\n";
	print "<input name=makehome type=radio value=0> $text{'no'}</td> </tr>\n";
	}

if ($access{'copy'} && $config{'user_files'} =~ /\S/) {
	print "<tr> <td><b>$text{'batch_copy'}</b></td>\n";
	print "<td><input name=copy type=radio value=1 checked> $text{'yes'}\n";
	print "<input name=copy type=radio value=0> $text{'no'}</td> </tr>\n";
	}

if ($access{'movehome'}) {
	print "<tr> <td><b>$text{'batch_movehome'}</b></td>\n";
	print "<td><input name=movehome type=radio value=1 checked> $text{'yes'}\n";
	print "<input name=movehome type=radio value=0> $text{'no'}</td> </tr>\n";
	}

if ($access{'chuid'}) {
	print "<tr> <td><b>$text{'batch_chuid'}</b></td>\n";
	print "<td><input type=radio name=chuid value=0> $text{'no'}\n";
	print "<input type=radio name=chuid value=1 checked> $text{'home'}\n";
	print "<input type=radio name=chuid value=2> ",
	      "$text{'uedit_allfiles'}</td></tr>\n";
	}

if ($access{'chgid'}) {
	print "<tr> <td><b>$text{'batch_chgid'}</b></td>\n";
	print "<td><input type=radio name=chgid value=0> $text{'no'}\n";
	print "<input type=radio name=chgid value=1 checked> $text{'home'}\n";
	print "<input type=radio name=chgid value=2> ",
	      "$text{'uedit_allfiles'}</td></tr>\n";
	}

print "<tr> <td><b>$text{'batch_delhome'}</b></td>\n";
print "<td><input name=delhome type=radio value=1 checked> $text{'yes'}\n";
print "<input name=delhome type=radio value=0> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'batch_crypt'}</b></td>\n";
print "<td><input name=crypt type=radio value=1> $text{'yes'}\n";
print "<input name=crypt type=radio value=0 checked> $text{'no'}</td> </tr>\n";

print "<tr> <td><input type=submit value=\"$text{'batch_upload'}\"></td> </tr>\n";
print "</table></form>\n";

&ui_print_footer("", $text{'index_return'});

