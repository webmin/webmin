#!/usr/local/bin/perl
# conf_misc.cgi
# Display other options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcm'}") unless $access{'conf_misc'};

&ui_print_header(undef, $text{'misc_title'}, "");

&get_share("global");
print "<form action=save_misc.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'misc_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'misc_debug'}</b></td>\n";
print "<td><select name=debug_level>\n";
foreach $d ("", 0 .. 10) {
	printf "<option value=\"$d\" %s> %s\n",
		&getval("debug level") eq $d ? "selected" : "",
		$d eq "" ? $text{'default'} : $d;
	}
print "</select></td>\n";

print "<td><b>$text{'misc_cachecall'}</b></td>\n";
printf "<td nowrap><input type=radio name=getwd_cache value=yes %s> $text{'yes'}\n",
	&istrue("getwd cache") ? "checked" : "";
printf "<input type=radio name=getwd_cache value=no %s> $text{'no'}</td> </tr>\n",
	&istrue("getwd cache") ? "" : "checked";

print "<tr> <td><b>$text{'misc_lockdir'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=lock_directory_def value=1 %s> $text{'default'}\n",
	&getval("lock directory") eq "" ? "checked" : "";
printf "&nbsp; <input type=radio name=lock_directory_def value=0 %s>\n",
	&getval("lock directory") eq "" ? "" : "checked";
printf "<input name=lock_directory size=30 value=\"%s\">\n",
	&getval("lock directory");
print &file_chooser_button("lock_directory", 1);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'misc_log'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=log_file_def value=1 %s> $text{'default'}\n",
	&getval("log file") eq "" ? "checked" : "";
printf "&nbsp; <input type=radio name=log_file_def value=0 %s>\n",
	&getval("log file") eq "" ? "" : "checked";
printf "<input name=log_file size=30 value=\"%s\">\n",
	&getval("log file");
print &file_chooser_button("log_file", 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'misc_maxlog'}</b></td>\n";
printf "<td nowrap><input type=radio name=max_log_size_def value=1 %s> $text{'default'}\n",
	&getval("max log size") eq "" ? "checked" : "";
printf "<input type=radio name=max_log_size_def value=0 %s>\n",
	&getval("max log size") eq "" ? "" : "checked";
printf "<input name=max_log_size size=5 value=\"%s\">kB</td>\n",
	&getval("max log size");

print "<tr> <td><b>$text{'misc_rawread'}</b></td>\n";
printf "<td nowrap><input type=radio name=read_raw value=yes %s> $text{'yes'}\n",
	&isfalse("read raw") ? "" : "checked";
printf "<input type=radio name=read_raw value=no %s> $text{'no'}</td>\n",
	&isfalse("read raw") ? "checked" : "";

print "<td><b>$text{'misc_rawwrite'}</b></td>\n";
printf "<td nowrap><input type=radio name=write_raw value=yes %s> $text{'yes'}\n",
	&isfalse("write raw") ? "" : "checked";
printf "<input type=radio name=write_raw value=no %s> $text{'no'}</td> </tr>\n",
	&isfalse("write raw") ? "checked" : "";

print "<td><b>$text{'misc_overlapread'}</b></td>\n";
printf "<td nowrap><input type=radio name=read_size_def value=1 %s> $text{'default'}\n",
	&getval("read size") eq "" ? "checked" : "";
printf "<input type=radio name=read_size_def value=0 %s>\n",
	&getval("read size") eq "" ? "" : "checked";
printf "<input name=read_size size=5 value=\"%s\">$text{'config_bytes'}</td> </tr>\n",
	&getval("read size");

print "<tr> <td><b>$text{'misc_chroot'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=root_directory_def value=1 %s> $text{'config_none'}\n",
	&getval("root directory") eq "" ? "checked" : "";
printf "&nbsp; <input type=radio name=root_directory_def value=0 %s>\n",
	&getval("root directory") eq "" ? "" : "checked";
printf "<input name=root_directory size=30 value=\"%s\">\n",
	&getval("root directory");
print &file_chooser_button("root_directory", 1);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'misc_smbrun'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=smbrun_def value=1 %s> $text{'default'}\n",
	&getval("smbrun") eq "" ? "checked" : "";
printf "&nbsp; <input type=radio name=smbrun_def value=0 %s>\n",
	&getval("smbrun") eq "" ? "" : "checked";
printf "<input name=smbrun size=30 value=\"%s\">\n",
	&getval("smbrun");
print &file_chooser_button("smbrun", 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'misc_clienttime'}</b></td>\n";
printf "<td><input name=time_offset size=4 value=\"%d\">$text{'config_mins'}</td>\n",
	&getval("time offset");

print "<td><b>$text{'misc_readprediction'}</b></td>\n";
printf "<td nowrap><input type=radio name=read_prediction value=yes %s> $text{'yes'}\n",
	&istrue("read prediction") ? "checked" : "";
printf "<input type=radio name=read_prediction value=no %s> $text{'no'}</td> </tr>\n",
	&istrue("read prediction") ? "" : "checked";

print "</table></tr></td></table><p>\n";
print "<input type=submit value=$text{'save'}></form>\n";

&ui_print_footer("", $text{'index_sharelist'});


