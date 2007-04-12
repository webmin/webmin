#!/usr/local/bin/perl
# edit_mkisofs.cgi
# Global (less common) mkisofs options

require './burner-lib.pl';
$access{'global'} || &error($text{'mkiofs_ecannot'});
&ui_print_header(undef, $text{'mkisofs_title'}, "");

print "<form action=save_mkisofs.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'mkisofs_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'mkisofs_novers'}</b></td>\n";
printf "<td><input type=radio name=novers value=0 %s> %s\n",
	$config{'novers'} ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=novers value=1 %s> %s</td>\n",
	$config{'novers'} ? 'checked' : '', $text{'no'};

print "<td><b>$text{'mkisofs_notrans'}</b></td>\n";
printf "<td><input type=radio name=notrans value=1 %s> %s\n",
	$config{'notrans'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=notrans value=0 %s> %s</td> </tr>\n",
	$config{'notrans'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'mkisofs_nobak'}</b></td>\n";
printf "<td><input type=radio name=nobak value=1 %s> %s\n",
	$config{'nobak'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=nobak value=0 %s> %s</td>\n",
	$config{'nobak'} ? '' : 'checked', $text{'no'};

print "<td><b>$text{'mkisofs_fsyms'}</b></td>\n";
printf "<td><input type=radio name=fsyms value=1 %s> %s\n",
	$config{'fsyms'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=fsyms value=0 %s> %s</td> </tr>\n",
	$config{'fsyms'} ? '' : 'checked', $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

