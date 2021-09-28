#!/usr/local/bin/perl
# edit_portsentry.cgi
# Display portsentry configuration menu

require './sentry-lib.pl';

$path = &has_command($config{'portsentry'});
if (!$path) {
	&ui_print_header(undef, $text{'portsentry_title'}, "");
	print "<p>",&text('portsentry_ecommand',
			  "<tt>$config{'portsentry'}</tt>", 
			  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

if (!-r $config{'portsentry_config'} && -r $config{'portsentry_alt_config'}) {
	system("cp $config{'portsentry_alt_config'} $config{'portsentry_config'}");
	}

# Get the version, if needed
&read_file("$module_config_directory/portsentry", \%portsentry);
@st = stat($path);
if ($st[7] != $portsentry{'size'} || $st[9] != $portsentry{'mtime'}) {
	$out = &backquote_command("$config{'portsentry'} -v 2>&1", 1);
	if ($out !~ /Version:\s+(\S+)/) {
		&ui_print_header(undef, $text{'portsentry_title'}, "");
		print "<p>",&text('portsentry_eversion',
				  "<tt>$config{'portsentry'}</tt>", 
				  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("", $text{'index_return'});
		exit;
		}
	$portsentry{'version'} = $1;
	$portsentry{'size'} = $st[7];
	$portsentry{'mtime'} = $st[9];
	&write_file("$module_config_directory/portsentry", \%portsentry);
	}

&ui_print_header(undef, $text{'portsentry_title'}, "", "portsentry", 0, 0, undef,
	&help_search_link("portsentry", "man", "doc"), undef, undef,
	&text('portsentry_version', $portsentry{'version'}));

if ($portsentry{'version'} >= 2) {
	print "<p>",&text('portsentry_eversion2',
			  "<tt>$config{'portsentry'}</tt>",
			  $portsentry{'version'}),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Show configuration form
$conf = &get_portsentry_config();

print "<form action=save_portsentry.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'portsentry_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$tcp_ports = &find_value("TCP_PORTS", $conf);
$udp_ports = &find_value("UDP_PORTS", $conf);
$tcp_adv = &find_value("ADVANCED_PORTS_TCP", $conf);
$udp_adv = &find_value("ADVANCED_PORTS_UDP", $conf);
$tcp_exc = &find_value("ADVANCED_EXCLUDE_TCP", $conf);
$udp_exc = &find_value("ADVANCED_EXCLUDE_UDP", $conf);

print "<tr> <td valign=top><b>$text{'portsentry_tmode'}</b></td> <td>\n";
printf "%s <input name=tports size=50 value='%s'><br>\n",
	$text{'portsentry_mode0'},
	join(" ", split(/,/, $tcp_ports));
$tcp_exc = join(" ", split(/,/, $tcp_exc));
print &text('portsentry_mode1',
	    "<input name=tadv size=8 value='$tcp_adv'>",
	    "<input name=texc size=20 value='$tcp_exc'>"),"</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'portsentry_umode'}</b></td> <td>\n";
printf "%s <input name=uports size=50 value='%s'><br>\n",
	$text{'portsentry_mode0'},
	join(" ", split(/,/, $udp_ports));
$udp_exc = join(" ", split(/,/, $udp_exc));
print &text('portsentry_mode1',
	    "<input name=uadv size=8 value='$udp_adv'>",
	    "<input name=uexc size=20 value='$udp_exc'>"),"</td> </tr>\n";

$tblock = &find_value("BLOCK_TCP", $conf);
print "<tr> <td><b>$text{'portsentry_tblock'}</b></td> <td>\n";
printf "<input type=radio name=tblock value=1 %s> $text{'yes'}\n",
	$tblock == 1 ? "checked" : "";
printf "<input type=radio name=tblock value=0 %s> $text{'no'}\n",
	$tblock == 0 ? "checked" : "";
printf "<input type=radio name=tblock value=2 %s> $text{'portsentry_kill'}\n",
	$tblock == 2 ? "checked" : "";
print "</td> </tr>\n";

$ublock = &find_value("BLOCK_UDP", $conf);
print "<tr> <td><b>$text{'portsentry_ublock'}</b></td> <td>\n";
printf "<input type=radio name=ublock value=1 %s> $text{'yes'}\n",
	$ublock == 1 ? "checked" : "";
printf "<input type=radio name=ublock value=0 %s> $text{'no'}\n",
	$ublock == 0 ? "checked" : "";
printf "<input type=radio name=ublock value=2 %s> $text{'portsentry_kill'}\n",
	$ublock == 2 ? "checked" : "";
print "</td> </tr>\n";

print "<tr> <td><b>$text{'portsentry_banner'}</b></td>\n";
printf "<td><input name=banner size=50 value='%s'></td> </tr>\n",
	&find_value("PORT_BANNER", $conf);

print "<tr> <td><b>$text{'portsentry_trigger'}</b></td>\n";
printf "<td><input name=trigger size=6 value='%s'></td> </tr>\n",
	&find_value("SCAN_TRIGGER", $conf);

if ($config{'portsentry_ignore'}) {
	$ign = $config{'portsentry_ignore'};
	}
else {
	$ign = &find_value("IGNORE_FILE", $conf);
	}
if ($ign) {
	print "<tr> <td valign=top><b>$text{'portsentry_ignore'}</b></td>\n";
	print "<td><textarea name=ignore rows=5 cols=50>\n";
	$lnum = 0;
	open(IGN, $ign);
	while(<IGN>) {
		if (/Do NOT edit below this/i) {
			$editbelow = $lnum-1;
			last;
			}
		s/#.*$//;
		print &html_escape($_) if (/\S/);
		$lnum++;
		}
	close(IGN);
	print "</textarea></td> </tr></table>\n";
	print "<input type=hidden name=editbelow value='$editbelow'>\n"
		if (defined($editbelow));
	}
print "</td></tr></table>\n";

@pids = &get_portsentry_pids();
if (@pids) {
	print "<input type=submit name=apply value='$text{'portsentry_save'}'></form>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'></form>\n";
	}

# Show start/stop buttons
print &ui_hr();
print "<table width=100%>\n";
$cmd = &portsentry_start_cmd();
if (@pids) {
	# Running .. offer to stop
	print "<form action=stop_portsentry.cgi>\n";
	print "<tr> <td><input type=submit ",
	      "value='$text{'portsentry_stop'}'></td>\n";
	print "<td>$text{'portsentry_stopdesc'}</td> </tr>\n";
	print "</form>\n";
	}
else {
	# Not running .. offer to start
	print "<form action=start_portsentry.cgi>\n";
	print "<tr> <td><input type=submit ",
	      "value='$text{'portsentry_start'}'></td>\n";
	print "<td>",&text('portsentry_startdesc', "<tt>$cmd</tt>"),
	      "</td> </tr> </form>\n";
	}
print "</table>\n";

&ui_print_footer("", $text{'index_return'});

