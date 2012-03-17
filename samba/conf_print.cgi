#!/usr/local/bin/perl
# conf_print.cgi
# Display printing options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcprint'}") unless $access{'conf_print'};
 
&ui_print_header(undef, $text{'print_title'}, "");

&get_share("global");

print "<form action=save_print.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'print_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'print_style'}</b></td>\n";
print "<td><select name=printing>\n";
printf "<option value=\"\" %s> $text{'default'}\n",
	&getval("printing") eq "" ? "selected" : "";
foreach $s ("bsd", "sysv", "hpux", "aix", "qnx", "plp", "cups", "lprng",
	    "softq") {
	printf "<option value=$s %s> %s\n",
		&getval("printing") eq $s ? "selected" : "", uc($s);
	}
print "</select></td>\n";

print "<td><b>$text{'print_show'}</b></td>\n";
printf "<td><input type=radio name=load_printers value=yes %s> $text{'yes'}\n",
	&istrue("load printers") ? "checked" : "";
printf "<input type=radio name=load_printers value=no %s> $text{'no'}</td></tr>\n",
	&istrue("load printers") ? "" : "checked";

print "<tr> <td><b>$text{'print_printcap'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=printcap_name_def value=1 %s> $text{'default'}\n",
	&getval("printcap name") eq "" ? "checked" : "";
printf "&nbsp;&nbsp; <input type=radio name=printcap_name_def value=0 %s>\n",
	&getval("printcap name") eq "" ? "" : "checked";
printf "<input name=printcap_name size=25 value=\"%s\">\n",
	&getval("printcap name");
print &file_chooser_button("printcap_name", 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'print_cachetime'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=lpq_cache_time_def value=1 %s> $text{'default'}\n",
	&getval("lpq cache time") == 0 ? "checked" : "";
printf "&nbsp;&nbsp; <input type=radio name=lpq_cache_time_def value=0 %s>\n",
	&getval("lpq cache time") == 0 ? "" : "checked";
printf "<input name=lpq_cache_time size=5 value=\"%s\"> $text{'config_secs'}</td> </tr>\n",
	&getval("lpq cache time");

print "</table></td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}></form>\n";

&ui_print_footer("", $text{'index_sharelist'});
