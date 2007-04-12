#!/usr/local/bin/perl
# edit_export.cgi
# Allow editing of one export to a client

require './exports-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create_export");
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit_export");
	@exps = &list_exports();
	$exp = $exps[$in{'idx'}];
	%opts = %{$exp->{'options'}};
	}

print "<form action=save_export.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<td colspan=3><input name=dir size=40 value=\"$exp->{'dir'}\">",
        &file_chooser_button("dir", 1),"</td> </tr>\n";

print "<tr> <td>",&hlink("<b>$text{'edit_active'}</b>","active"),"</td>\n";
printf "<td colspan=3><input type=radio name=active value=1 %s> %s\n",
        $in{'new'} || $exp->{'active'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=active value=0 %s> %s</td> </tr>\n",
        $in{'new'} || $exp->{'active'} ? '' : 'checked', $text{'no'};

&more_detail_fields();

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_security'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&security_fields();

print "</table></td></tr></table>\n";
if (!$in{'new'}) {
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n";
	print "</tr></table>\n";
	}
else {
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\">\n";
	}

&ui_print_footer("", $text{'index_return'});

