#!/usr/local/bin/perl
# edit_dialin.cgi
# Display a caller-ID number for editing

require './pap-lib.pl';
$access{'dialin'} || &error($text{'dialin_ecannot'});
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'dialin_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'dialin_edit'}, "");
	@dialin = &parse_dialin_config();
	$dialin = $dialin[$in{'idx'}];
	}

print "<form action=save_dialin.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'dialin_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

$mode = $dialin->{'number'} eq 'all' ? 0 :
	$dialin->{'number'} eq 'none' ? 1 : 2;
print "<tr> <td valign=top><b>$text{'dialin_number'}</b></td>\n";
printf "<td><input type=radio name=mode value=0 %s> %s<br>\n",
	$mode == 0 ? "checked" : "", $text{'dialin_all'};
printf "<input type=radio name=mode value=1 %s> %s<br>\n",
	$mode == 1 ? "checked" : "", $text{'dialin_none'};
printf "<input type=radio name=mode value=2 %s> %s\n",
	$mode == 2 ? "checked" : "", $text{'dialin_match'};
printf "<input name=number size=15 value='%s'></td>\n",
	$mode == 2 ? $dialin->{'number'} : undef;

print "<td valign=top><b>$text{'dialin_ad'}</b></td>\n";
printf "<td valign=top><input type=radio name=allow value=1 %s> %s\n",
	$dialin->{'not'} ? "" : "checked", $text{'dialin_allow'};
printf "<input type=radio name=allow value=0 %s> %s</td> </tr>\n",
	$dialin->{'not'} ? "checked" : "", $text{'dialin_deny'};

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";

&ui_print_footer("list_dialin.cgi", $text{'dialin_return'});

