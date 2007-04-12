#!/usr/local/bin/perl
# edit_inc.cgi
# Edit an include file line

require './procmail-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'inc_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'inc_title2'}, "");
	@conf = &get_procmailrc();
	$inc = $conf[$in{'idx'}];
	}

print "<form action=save_inc.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'inc_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'inc_inc'}</b></td>\n";
printf "<td><input name=inc size=60 value='%s'> %s</td> </tr>\n",
	&html_escape($inc->{'include'}), &file_chooser_button("inc");

print "</table></td></tr></table>\n";

# Show save buttons
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

&ui_print_footer("", $text{'index_return'});

