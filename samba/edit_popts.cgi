#!/usr/local/bin/perl
# edit_popts.cgi
# Edit print-share specific options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvpopt'}")
        unless &can('ro', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'print_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'print_title2'}, "");
	}
&get_share($s);

print "<form action=save_popts.cgi>\n";
print "<input type=hidden name=old_name value=\"$s\">\n";

# Printer options
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'print_option'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'print_minspace'}</b></td>\n";
printf "<td><input name=min_print_space size=5 value=\"%d\"></td>\n",
	&getval("min print space");

print "<td><b>$text{'print_postscript'}</b></td>\n";
print "<td>",&yesno_input("postscript"),"</td> </tr>\n";

print "<tr> <td><b>$text{'print_command'}</b></td>\n";
printf "<td colspan=3>\n";
printf "<input type=radio name=print_command_def value=1 %s> $text{'default'}\n",
	&getval("print command") eq "" ? "checked" : "";
printf "&nbsp;&nbsp;<input type=radio name=print_command_def value=0 %s>\n",
	&getval("print command") ne "" ? "checked" : "";
printf "<input name=print_command size=30 value=\"%s\"></td> </tr>\n",
	&getval("print command");

print "<tr> <td><b>$text{'print_queue'}</b></td>\n";
printf "<td colspan=3>\n";
printf "<input type=radio name=lpq_command_def value=1 %s> $text{'default'}\n",
	&getval("lpq command") eq "" ? "checked" : "";
printf "&nbsp;&nbsp;<input type=radio name=lpq_command_def value=0 %s>\n",
	&getval("lpq command") ne "" ? "checked" : "";
printf "<input name=lpq_command size=30 value=\"%s\"></td> </tr>\n",
	&getval("lpq command");

print "<tr> <td><b>$text{'print_delete'}</b></td>\n";
printf "<td colspan=3>\n";
printf "<input type=radio name=lprm_command_def value=1 %s> $text{'default'}\n",
	&getval("lprm command") eq "" ? "checked" : "";
printf "&nbsp;&nbsp;<input type=radio name=lprm_command_def value=0 %s>\n",
	&getval("lprm command") ne "" ? "checked" : "";
printf "<input name=lprm_command size=30 value=\"%s\"></td> </tr>\n",
	&getval("lprm command");

print "<tr> <td><b>$text{'print_pause'}</b></td>\n";
printf "<td colspan=3>\n";
printf "<input type=radio name=lppause_command_def value=1 %s> $text{'config_none'}\n",
	&getval("lppause command") eq "" ? "checked" : "";
printf "&nbsp;&nbsp;<input type=radio name=lppause_command_def value=0 %s>\n",
	&getval("lppause command") ne "" ? "checked" : "";
printf "<input name=lppause_command size=30 value=\"%s\"></td> </tr>\n",
	&getval("lppause command");

print "<tr> <td><b>$text{'print_unresume'}</b></td>\n";
printf "<td colspan=3>\n";
printf "<input type=radio name=lpresume_command_def value=1 %s> $text{'config_none'}\n",
	&getval("lpresume command") eq "" ? "checked" : "";
printf "&nbsp;&nbsp;<input type=radio name=lpresume_command_def value=0 %s>\n",
	&getval("lpresume command") ne "" ? "checked" : "";
printf "<input name=lpresume_command size=30 value=\"%s\"></td> </tr>\n",
	&getval("lpresume command");

print "<tr> <td><b>$text{'print_driver'}</b></td>\n"; 
print "<td colspan=3>\n";
printf "<input type=radio name=printer_driver_def value=1 %s> $text{'config_none'}\n",
	&getval("printer driver") eq "" ? "checked" : "";
printf "&nbsp;&nbsp;<input type=radio name=printer_driver_def value=0 %s>\n",
	&getval("printer driver") ne "" ? "checked" : "";
printf "<input name=printer_driver size=30 value=\"%s\"></td> </tr>\n",
	&getval("printer driver");

print "</table> </td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}>"
	if &can('wO', \%access, $in{'share'}); 
print "</form><p>\n";

&ui_print_footer("edit_pshare.cgi?share=".&urlize($s), $text{'index_printershare'},
	"", $text{'index_sharelist'});

