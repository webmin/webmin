#!/usr/local/bin/perl
# edit_export.cgi
# Display a form for editing or creating an export

require './sgiexports-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&header($text{'edit_title1'}, "");
	}
else {
	&header($text{'edit_title2'}, "");
	@exports = &get_exports();
	$export = $exports[$in{'idx'}];
	$opts = $export->{'opts'};
	}
print &ui_hr();

print "<form action=save_export.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_dir'}</b></td>\n";
printf "<td colspan=3><input name=dir size=40 value='%s'> %s</td> </tr>\n",
	$export->{'dir'}, &file_chooser_button("dir", 1);

print "<tr> <td><b>$text{'edit_hosts'}</b></td>\n";
printf "<td colspan=3><input name=hosts size=50 value='%s'></td> </tr>\n",
	join(" ", @{$export->{'hosts'}});

print "<tr> <td><b>$text{'edit_ro'}</b></td>\n";
printf "<td><input type=radio name=ro value=1 %s> %s\n",
	defined($opts->{'ro'}) ? "checked" : "", $text{'yes'};
printf "<input type=radio name=ro value=0 %s> %s</td> </tr>\n",
	defined($opts->{'ro'}) ? "" : "checked", $text{'no'};

print "<tr> <td><b>$text{'edit_wsync'}</b></td>\n";
printf "<td><input type=radio name=wsync value=1 %s> %s\n",
	defined($opts->{'wsync'}) ? "checked" : "", $text{'yes'};
printf "<input type=radio name=wsync value=0 %s> %s</td> </tr>\n",
	defined($opts->{'wsync'}) ? "" : "checked", $text{'no'};

$am = $opts->{'anon'} eq "-1" ? 2 : defined($opts->{'anon'}) ? 0 : 1;
print "<tr> <td><b>$text{'edit_anon'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=anon_def value=1 %s> %s",
	$am == 1 ? "checked" : "", $text{'edit_anon1'};
printf "<input type=radio name=anon_def value=2 %s> %s",
	$am == 2 ? "checked" : "", $text{'edit_anon2'};
printf "<input type=radio name=anon_def value=0 %s> %s\n",
	$am == 0 ? "checked" : "", $text{'edit_anon0'};
print &unix_user_input("anon", $am == 0 ? $opts->{'anon'} : ""),"</td> </tr>\n";

print "</table></td></tr></table><p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_rw'}</b></td> ",
      "<td><b>$text{'edit_root'}</b></td> ",
      "<td><b>$text{'edit_access'}</b></td> </tr>\n";
print "<tr $cb>\n";

printf "<td><input type=radio name=rw_def value=1 %s> %s<br>\n",
	defined($opts->{'rw'}) ? "" : "checked", $text{'edit_all'};
printf "<input type=radio name=rw_def value=0 %s> %s<br>\n",
	defined($opts->{'rw'}) ? "checked" : "", $text{'edit_sel'};
print "<textarea name=rw rows=5 cols=20>",
	join("\n", split(/:/, $opts->{'rw'})),"</textarea></td>\n";

printf "<td><input type=radio name=root_def value=1 %s> %s<br>\n",
	defined($opts->{'root'}) ? "" : "checked", $text{'edit_none'};
printf "<input type=radio name=root_def value=0 %s> %s<br>\n",
	defined($opts->{'root'}) ? "checked" : "", $text{'edit_sel'};
print "<textarea name=root rows=5 cols=20>",
	join("\n", split(/:/, $opts->{'root'})),"</textarea></td>\n";

printf "<td><input type=radio name=access_def value=1 %s> %s<br>\n",
	defined($opts->{'access'}) ? "" : "checked", $text{'edit_none'};
printf "<input type=radio name=access_def value=0 %s> %s<br>\n",
	defined($opts->{'access'}) ? "checked" : "", $text{'edit_sel'};
print "<textarea name=access rows=5 cols=20>",
	join("\n", split(/:/, $opts->{'access'})),"</textarea></td>\n";

print "</tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

print &ui_hr();
&footer("", $text{'index_return'});

