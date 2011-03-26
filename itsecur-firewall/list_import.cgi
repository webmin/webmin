#!/usr/bin/perl
# Show a form for importing rules in CSV format

require './itsecur-lib.pl';
&can_edit_error("import");
&check_zip();
&header($text{'import_title'}, "",
	undef, undef, undef, undef, &apply_button());

foreach $i (1 .. (&supports_time() ? 4 : 3)) {
	$prog = $i == 1 ? "import_rules.cgi" :
		$i == 2 ? "import_servs.cgi" :
		$i == 3 ? "import_groups.cgi" :
		$i == 4 ? "import_times.cgi" : undef;
	print "<hr>\n";
	print $text{'import_desc'.$i},"<p>\n";
	print "<form action=$prog enctype=multipart/form-data method=post>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>",$text{'import_header'.$i},"</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	# Show source
	print "<tr> <td valign=top><b>$text{'import_src'}</b></td> <td>\n";
	printf "<input type=radio name=src_def value=1 %s> %s\n",
		$mode != 1 ? "checked" : "", $text{'restore_src1'};
	print "<input name=file type=file size=20><br>\n";
	printf "<input type=radio name=src_def value=0 %s> %s\n",
		$mode == 1 ? "checked" : "", $text{'restore_src0'};
	printf "<input name=src size=40 value='%s'> %s</td> </tr>\n",
		$mode == 1 ? $dest[0] : undef, &file_chooser_button("src");

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'import_ok'}'></form>\n";
	}

print "<hr>\n";
&footer("", $text{'index_return'});

