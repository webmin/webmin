#!/usr/local/bin/perl
# edit_conf.cgi
# Display ha_conf options

require './heartbeat-lib.pl';
&ui_print_header(undef, $text{'conf_title'}, "");

@conf = &get_ha_config();
print "<form action=save_conf.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'conf_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@serials = &find("serial", \@conf);
print "<tr> <td><b>$text{'conf_serials'}</b></td>\n";
print "<td>\n";
for($i=0; $i<=@serials; $i++) {
	local $sfound;
	print "<select name=serial_$i>\n";
	opendir(DIR, "/dev");
	printf "<option value='' %s>%s</option>\n",
		$serials[$i] ? "" : "selected",
		$i ? "&nbsp;" : $text{'conf_none'};
	foreach $p (glob($config{'serials'})) {
		printf "<option %s>%s</option>\n",
			$p eq $serials[$i] ? "selected" : "", $p;
		$sfound++ if ($p eq $serials[$i]);
		}
	closedir(DIR);
	print "<option selected>$serials[$i]</option>\n" if ($serials[$i] && !$sfound);
	print "</select>\n";
	}
print "</td> </tr>\n";

$baud = &find("baud", \@conf);
print "<tr><td><b>$text{'conf_baud'}</b></td> <td>\n";
printf "<input type=radio name=baud_def value=1 %s> %s\n",
	$baud ? "" : "checked", $text{'default'};
printf "<input type=radio name=baud_def value=0 %s>\n",
	$baud ? "checked" : "";
printf "<input name=baud size=6 value='%s'></td> </tr>\n", $baud;

# changed (Christof Amelunxen, 22.08.2003)
# udp directive replaced by bcast
@bcasts = &find("bcast", \@conf);
print "<tr> <td><b>$text{'conf_bcasts'}</b></td> <td>\n";
printf "<input type=radio name=bcasts_def value=1 %s> %s\n",
	@bcasts ? "" : "checked", $text{'conf_none'};
printf "<input type=radio name=bcasts_def value=0 %s>\n",
	@bcasts ? "checked" : "";
printf "<input name=bcasts size=20 value='%s'></td>\n",
	join(" ", @bcasts);

$udpport = &find("udpport", \@conf);
print "<tr><td><b>$text{'conf_udpport'}</b></td> <td>\n";
printf "<input type=radio name=udpport_def value=1 %s> %s\n",
	$udpport ? "" : "checked", $text{'default'};
printf "<input type=radio name=udpport_def value=0 %s>\n",
	$udpport ? "checked" : "";
printf "<input name=udpport size=5 value='%s'></td> </tr>\n", $udpport;

$mcast = &find("mcast", \@conf);
print "<tr><td valign=top><b>$text{'conf_mcast'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mcast_def value=1 %s> %s<br>\n",
	$mcast ? "" : "checked", $text{'conf_none'};
printf "<input type=radio name=mcast_def value=0 %s>\n",
	$mcast ? "checked" : "";
@mcast = split(/\s+/, $mcast);
$mloop = "<select name=mcast_loop>\n";
$mloop .= sprintf "<option value=0 %s>%s</option>\n",
		$mcast[4] ? "" : "selected", $text{'conf_disabled'};
$mloop .= sprintf "<option value=1 %s>%s</option>\n",
		$mcast[4] ? "selected" : "", $text{'conf_enabled'};
$mloop .= "</select>\n";
print &text('conf_mcastv',
	    "<input name=mcast_dev size=4 value='$mcast[0]'>",
	    "<input name=mcast_ip size=15 value='$mcast[1]'>",
	    "<input name=mcast_port size=5 value='$mcast[2]'>",
	    "<input name=mcast_ttl size=3 value='$mcast[3]'>",
	    $mloop),"</td> </tr>\n";

$keepalive = &find("keepalive", \@conf);
print "<tr> <td><b>$text{'conf_keepalive'}</b></td> <td nowrap>\n";
printf "<input type=radio name=keepalive_def value=1 %s> %s\n",
	$keepalive ? "" : "checked", $text{'default'};
printf "<input type=radio name=keepalive_def value=0 %s>\n",
	$keepalive ? "checked" : "";
printf "<input name=keepalive size=6 value='%s'> %s</td>\n",
	$keepalive, $text{'conf_secs'};

$deadtime = &find("deadtime", \@conf);
print "<tr><td><b>$text{'conf_deadtime'}</b></td> <td nowrap>\n";
printf "<input type=radio name=deadtime_def value=1 %s> %s\n",
	$deadtime ? "" : "checked", $text{'default'};
printf "<input type=radio name=deadtime_def value=0 %s>\n",
	$deadtime ? "checked" : "";
printf "<input name=deadtime size=6 value='%s'> %s</td> </tr>\n",
	$deadtime, $text{'conf_secs'};

$watchdog = &find("watchdog", \@conf);
print "<tr> <td><b>$text{'conf_watchdog'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=watchdog_def value=1 %s> %s\n",
	$watchdog ? "" : "checked", $text{'conf_none'};
printf "<input type=radio name=watchdog_def value=0 %s>\n",
	$watchdog ? "checked" : "";
printf "<input name=watchdog size=25 value='%s'> %s</td> </tr>\n",
	$watchdog, &file_chooser_button("watchdog");

print "<tr> <td valign=top><b>$text{'conf_node'}</b></td> <td colspan=3>\n";
print "<textarea name=node rows=4 cols=40>",
	join("\n", &find("node", \@conf)),"</textarea></td> </tr>\n";

$logfile = &find("logfile", \@conf);
print "<tr> <td><b>$text{'conf_logfile'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=logfile_def value=1 %s> %s\n",
	$logfile ? "" : "checked", $text{'conf_none'};
printf "<input type=radio name=logfile_def value=0 %s>\n",
	$logfile ? "checked" : "";
printf "<input name=logfile size=40 value='%s'> %s</td> </tr>\n",
	$logfile, &file_chooser_button("logfile");

$logfacility = &find("logfacility", \@conf);
print "<tr> <td><b>$text{'conf_logfacility'}</b></td> <td>\n";
printf "<input type=radio name=logfacility_def value=1 %s> %s\n",
	$logfacility ? "" : "checked", $text{'default'};
printf "<input type=radio name=logfacility_def value=0 %s>\n",
	$logfacility ? "checked" : "";
if (&foreign_check("syslog")) {
	local %sconfig = &foreign_config("syslog");
	print "<select name=logfacility>\n";
	foreach $f (split(/\s+/, $sconfig{'facilities'})) {
		printf "<option %s>%s</option>\n",
			$f eq $logfacility ? "selected" : "", $f;
		}
	print "</select>\n";
	}
else {
	printf "<input name=logfacility size=15 value='%s'>\n", $logfacility;
	}
print "</td>\n";

$initdead = &find("initdead", \@conf);
print "<tr><td><b>$text{'conf_initdead'}</b></td> <td>\n";
printf "<input type=radio name=initdead_def value=1 %s> %s\n",
	$initdead ? "" : "checked", $text{'default'};
printf "<input type=radio name=initdead_def value=0 %s>\n",
	$initdead ? "checked" : "";
printf "<input name=initdead size=6 value='%s'> %s</td> </tr>\n",
	$initdead, $text{'conf_secs'};

# changed (Christof Amelunxen, 22.08.2003)
# define failback behaviour
print "<tr><td><b>$text{'conf_nice_failback'}</b></td> <td>\n";
if (&version_atleast(1, 2, 0)) {
	$auto_failback = &find("auto_failback", \@conf);
	foreach $aa ("on", "off", "legacy", "") {
		printf "<input type=radio name=auto_failback value=%s %s> %s\n",
			$aa, $auto_failback eq $aa ? "checked" : "",
			$text{'conf_auto_'.$aa};
		}
	}
else {
	$nice_failback = &find("nice_failback", \@conf);
	printf "<input type=radio name=nice_failback_def value=1 %s> %s\n",
		$nice_failback ? "checked" : "", $text{'conf_enabled'};
	printf "<input type=radio name=nice_failback_def value=0 %s> %s\n",
		$nice_failback ? "" : "checked", $text{'conf_disabled'};
	}
print "</td> </tr>\n";

print "</table></table>\n";
print "<input type=submit value='$text{'conf_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

