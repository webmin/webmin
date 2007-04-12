#!/usr/local/bin/perl
# edit_misc.cgi
# Display all other SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'misc_title'}, "", "misc");
$conf = &get_sshd_config();

print "<form action=save_misc.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'misc_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

&scmd();
$x11 = &find_value("X11Forwarding", $conf);
print "<td><b>$text{'misc_x11'}</b></td> <td nowrap>\n";
if ($version{'type'} eq 'ssh') {
	printf "<input type=radio name=x11 value=1 %s> %s\n",
		lc($x11) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=x11 value=0 %s> %s</td>\n",
		lc($x11) eq 'no' ? "checked" : "", $text{'no'};
	}
else {
	printf "<input type=radio name=x11 value=1 %s> %s\n",
		lc($x11) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=x11 value=0 %s> %s</td>\n",
		lc($x11) eq 'yes' ? "" : "checked", $text{'no'};
	}
&ecmd();

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	&scmd();
	$xoff = &find_value("X11DisplayOffset", $conf);
	print "<td><b>$text{'misc_xoff'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=xoff_def value=1 %s> %s\n",
		$xoff ? "" : "checked", $text{'default'};
	printf "<input type=radio name=xoff_def value=0 %s>\n",
		$xoff ? "checked" : "";
	print "<input name=xoff size=4 value='$xoff'></td>\n";
	&ecmd();

	if ($version{'type'} eq 'ssh' || $version{'number'} >= 2) {
		&scmd(1);
		$xauth = &find_value("XAuthLocation", $conf);
		print "<td><b>$text{'misc_xauth'}</b></td> <td colspan=3>\n";
		printf "<input type=radio name=xauth_def value=1 %s> %s\n",
			$xauth ? "" : "checked", $text{'default'};
		printf "<input type=radio name=xauth_def value=0 %s>\n",
			$xauth ? "checked" : "";
		print "<input name=xauth size=50 value='$xauth'></td>\n";
		&ecmd();
		}
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&scmd();
	$umask = &find_value("Umask", $conf);
	print "<td><b>$text{'misc_umask'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=umask_def value=1 %s> %s\n",
		$umask ? "" : "checked", $text{'misc_umask_def'};
	printf "<input type=radio name=umask_def value=0 %s>\n",
		$umask ? "checked" : "";
	print "<input name=umask size=4 value='$umask'></td>\n";
	&ecmd();
	}

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

