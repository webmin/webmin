#!/usr/local/bin/perl
# edit_global.cgi
# Edit global MON paths

require './mon-lib.pl';
$conf = &get_mon_config();
&ui_print_header(undef, $text{'global_title'}, "");

print "<form action=save_global.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'global_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$maxprocs = &find_value("maxprocs", $conf);
print "<tr> <td><b>$text{'global_maxprocs'}</b></td> <td>\n";
print "<input name=maxprocs size=6 value='$maxprocs'></td>\n";

$histlength = &find_value("histlength", $conf);
print "<td><b>$text{'global_histlength'}</b></td> <td>\n";
print "<input name=histlength size=6 value='$histlength'></td> </tr>\n";

$authtype = &find_value("authtype", $conf);
print "<tr> <td><b>$text{'global_authtype'}</b></td>\n";
print "<td><select name=authtype>\n";
foreach $t ('', 'getpwnam', 'userfile', 'shadow') {
	printf "<option value='%s' %s>%s</option>\n",
		$t, $authtype eq $t ? "selected" : "",
		$text{"global_authtype_$t"};
	}
print "</select></td> </tr>\n";

$userfile = &find_value("userfile", $conf);
print "<tr> <td><b>$text{'global_userfile'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=userfile_def value=1 %s> %s\n",
	$userfile ? "" : "checked", $text{'default'};
printf "<input type=radio name=userfile_def value=0 %s>\n",
	$userfile ? "checked" : "";
print "<input name=userfile size=40 value='$userfile'> ",
	&file_chooser_button("userfile", 0),"</td> </tr>\n";

$alertdir = &find_value("alertdir", $conf);
print "<tr> <td><b>$text{'global_alertdir'}</b></td> <td colspan=3>\n";
print "<input name=alertdir size=40 value='$alertdir'> ",
	&file_chooser_button("alertdir", 1),"</td> </tr>\n";

$mondir = &find_value("mondir", $conf);
print "<tr> <td><b>$text{'global_mondir'}</b></td> <td colspan=3>\n";
print "<input name=mondir size=40 value='$mondir'> ",
	&file_chooser_button("mondir", 1),"</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

