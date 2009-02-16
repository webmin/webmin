#!/usr/local/bin/perl
# edit_misc.cgi
# Display all other SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'misc_title'}, "", "misc");
$conf = &get_sshd_config();

print &ui_form_start("save_misc.cgi");
print &ui_table_start($text{'misc_header'}, "width=100%", 2);

# X11 port forwarding
$x11 = &find_value("X11Forwarding", $conf);
print &ui_table_row($text{'misc_x11'},
	&ui_yesno_radio("x11", lc($x11) eq 'no' ? 0 :
			       lc($x11) eq 'yes' ? 1 :
			       $version{'type'} eq 'ssh' ? 1 : 0));

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	# X display offset
	$xoff = &find_value("X11DisplayOffset", $conf);
	print &ui_table_row($text{'misc_xoff'},
		&ui_opt_textbox("xoff", $xoff, 6, $text{'default'}));

	if ($version{'type'} eq 'ssh' || $version{'number'} >= 2) {
		# Path to xauth
		$xauth = &find_value("XAuthLocation", $conf);
		print &ui_table_row($text{'misc_xauth'},
			&ui_opt_textbox("xauth", $xauth, 40, $text{'default'}).
			" ".&file_chooser_button("xauth"));
		}
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	# Default umask
	$umask = &find_value("Umask", $conf);
	print &ui_table_row($text{'misc_umask'},
		&ui_opt_textbox("umask", $umask, 4, $text{'misc_umask_def'}));
	}

# Syslog facility
# XXX
&scmd();
$syslog = &find_value("SyslogFacility", $conf);
print "<td><b>$text{'misc_syslog'}</b></td> <td nowrap>\n";
printf "<input type=radio name=syslog_def value=1 %s> %s\n",
	$syslog ? "" : "checked", $text{'default'};
printf "<input type=radio name=syslog_def value=0 %s>\n",
	$syslog ? "checked" : "";
print "<select name=syslog>\n";
foreach $s (DAEMON, USER, AUTH, LOCAL0,  LOCAL1,  LOCAL2,  LOCAL3,
            LOCAL4,  LOCAL5,  LOCAL6,  LOCAL7) {
	printf "<option %s>%s\n",
		lc($s) eq lc($syslog) ? 'selected' : '', $s;
	}
print "</select></td>\n";
&ecmd();

if ($version{'type'} eq 'openssh') {
	&scmd();
	$loglevel = &find_value("LogLevel", $conf);
	print "<td><b>$text{'misc_loglevel'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=loglevel_def value=1 %s> %s\n",
		$loglevel ? "" : "checked", $text{'default'};
	printf "<input type=radio name=loglevel_def value=0 %s>\n",
		$loglevel ? "checked" : "";
	print "<select name=loglevel>\n";
	foreach $s (QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG) {
		printf "<option %s>%s\n",
			lc($s) eq lc($loglevel) ? 'selected' : '', $s;
		}
	print "</select></td>\n";
	&ecmd();
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	&scmd();
	$bits = &find_value("ServerKeyBits", $conf);
	print "<td><b>$text{'misc_bits'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=bits_def value=1 %s> %s\n",
		$bits ? "" : "checked", $text{'default'};
	printf "<input type=radio name=bits_def value=0 %s>\n",
		$bits ? "checked" : "";
	print "<input name=bits size=4 value='$bits'> $text{'bits'}</td>\n";
	&ecmd();
	}

if ($version{'type'} eq 'ssh') {
	&scmd();
	$quiet = &find_value("QuietMode", $conf);
	print "<td><b>$text{'misc_quiet'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=quiet value=1 %s> %s\n",
		lc($quiet) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=quiet value=0 %s> %s</td>\n",
		lc($quiet) eq 'no' ? "checked" : "", $text{'no'};
	&ecmd();
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	&scmd();
	$regen = &find_value("KeyRegenerationInterval", $conf);
	print "<td><b>$text{'misc_regen'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=regen_def value=1 %s> %s\n",
		$regen ? "" : "checked", $text{'misc_regen_def'};
	printf "<input type=radio name=regen_def value=0 %s>\n",
		$regen ? "checked" : "";
	print "<input name=regen size=6 value='$regen'> $text{'secs'}</td>\n";
	&ecmd();
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&scmd();
	$fascist = &find_value("FascistLogging", $conf);
	print "<td><b>$text{'misc_fascist'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=fascist value=1 %s> %s\n",
		lc($fascist) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=fascist value=0 %s> %s</td>\n",
		lc($fascist) eq 'yes' ? "" : "checked", $text{'no'};
	&ecmd();
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	if ($version{'type'} eq 'ssh' || $version{'number'} >= 2) {
		&scmd(1);
		$pid = &find_value("PidFile", $conf);
		print "<td><b>$text{'misc_pid'}</b></td> <td colspan=3>\n";
		printf "<input type=radio name=pid_def value=1 %s> %s\n",
			$pid ? "" : "checked", $text{'default'};
		printf "<input type=radio name=pid_def value=0 %s>\n",
			$pid ? "checked" : "";
		print "<input name=pid size=50 value='$pid'></td>\n";
		&ecmd();
		}
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3.2) {
	&scmd();
	$separ = &find_value("UsePrivilegeSeparation", $conf);
	print "<td><b>$text{'misc_separ'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=separ value=1 %s> %s\n",
		lc($separ) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=separ value=0 %s> %s</td>\n",
		lc($separ) eq 'no' ? "checked" : "", $text{'no'};
	&ecmd();
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

