#!/usr/local/bin/perl
# edit_options.cgi
# Display list of options for PPP, and show if mgetty has autoPPP mode enabled

require './pap-lib.pl';
$access{'options'} || &error($text{'options_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'options_title'}, "");
$of = $config{'ppp_options'};
if ($in{'file'} =~ /^\Q$of\E\.ttyS(\d+)$/) {
	$tty = "ttyS$1";
	print "<center><font size=+1>",&text('options_serial', $1+1),
	      "</font></center>\n";
	}
elsif ($in{'file'} =~ /^\Q$of\E\.(\S+)$/) {
	$tty = $1;
	$tty =~ s/\./\//g;
	print "<center><font size=+1>",&text('options_dev', "<tt>$tty</tt>"),
	      "</font></center>\n";
	}

# Check if the PPP daemon is actually installed
if (!&has_command($config{'pppd'})) {
	print "<p>",&text('options_ecmd', "<tt>$config{'pppd'}</tt>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Check if the pppd is the linux one
$out = `$config{'pppd'} -v 2>&1`;
if ($out !~ /version\s+([0-9\.]+)/) {
	print "<p>",&text('options_epppd', "<tt>$config{'pppd'}</tt>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

@opts = &parse_ppp_options($in{'file'} || $of);
if (!$in{'file'}) {
	# Check for the mgetty login config file
	if (!-r $config{'login_config'}) {
		print "<p>",&text('options_elogin',
		    "<tt>$config{'login_config'}</tt>",
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("", $text{'index_return'});
		exit;
		}
	@login = &parse_login_config();
	}

print "<p>$text{'options_desc'}<p>\n" if (!$in{'file'});

print "<form action=save_options.cgi>\n";
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<input type=hidden name=tty value='$tty'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'options_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if (!$in{'file'}) {
	# Show if autoPPP is being used or not
	($auto) = grep { $_->{'user'} eq "/AutoPPP/" } @login;
	print "<tr> <td colspan=2><b>$text{'options_autoppp'}</b></td>\n";
	printf "<td><input name=auto type=radio value=1 %s> %s\n",
		$auto ? "checked" : "", $text{'yes'};
	printf "<input name=auto type=radio value=0 %s> %s</td> </tr>\n",
		$auto ? "" : "checked", $text{'no'};
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	}

($ip) = grep { $_->{'local'} } @opts;
print "<tr> <td><b>$text{'options_ip'}</b></td>\n";
printf "<td colspan=3><input type=radio name=ip_def value=1 %s> %s\n",
	$ip ? "" : "checked", $text{'options_auto'};
printf "<input type=radio name=ip_def value=0 %s>\n",
	$ip ? "checked" : "";
printf "%s <input name=local size=15 value='%s'>\n",
	$text{'options_local'}, $ip->{'local'};
printf "%s <input name=remote size=15 value='%s'></td> </tr>\n",
	$text{'options_remote'}, $ip->{'remote'};

$nm = &find("netmask", \@opts);
print "<tr> <td><b>$text{'options_netmask'}</b></td>\n";
printf "<td><input type=radio name=netmask_def value=1 %s> %s\n",
	$nm ? "" : "checked", $text{'default'};
printf "<input type=radio name=netmask_def value=0 %s>\n",
	$nm ? "checked" : "";
printf "<input name=netmask size=15 value='%s'></td>\n", $nm->{'value'};

$proxy = &find("proxyarp", \@opts);
print "<td><b>$text{'options_proxyarp'}</b></td>\n";
printf "<td><input type=radio name=proxyarp value=1 %s> %s\n",
	$proxy ? "checked" : "", $text{'yes'};
printf "<input type=radio name=proxyarp value=0 %s> %s</td> </tr>\n",
	$proxy ? "" : "checked", $text{'no'};

$lock = &find("lock", \@opts);
print "<tr> <td><b>$text{'options_lock'}</b></td>\n";
printf "<td><input type=radio name=lock value=1 %s> %s\n",
	$lock ? "checked" : "", $text{'yes'};
printf "<input type=radio name=lock value=0 %s> %s</td>\n",
	$lock ? "" : "checked", $text{'no'};

$modem = &find("modem", \@opts);
$local = &find("local", \@opts);
print "<td><b>$text{'options_ctrl'}</b></td>\n";
print "<td><select name=ctrl>\n";
printf "<option value=0 %s>%s</option>\n",
	$local ? "selected" : "", $text{'options_ctrl0'};
printf "<option value=1 %s>%s</option>\n",
	$modem ? "selected" : "", $text{'options_ctrl1'};
printf "<option value=2 %s>%s</option>\n",
	$modem || $local ? "" : "selected", $text{'default'};
print "</select></td> </tr>\n";

$auth = &find("auth", \@opts);
$noauth = &find("noauth", \@opts);
print "<tr> <td><b>$text{'options_auth'}</b></td>\n";
printf "<td colspan=3><input type=radio name=auth value=0 %s> %s\n",
	$noauth || $auth ? "" : "checked", $text{'options_auth0'};
printf "<input type=radio name=auth value=1 %s> %s\n",
	$noauth ? "checked" : "", $text{'options_auth1'};
printf "<input type=radio name=auth value=2 %s> %s</td> </tr>\n",
	$auth ? "checked" : "", $text{'options_auth2'};

$login = &find("login", \@opts);
print "<tr> <td><b>$text{'options_login'}</b></td>\n";
printf "<td><input type=radio name=login value=1 %s> %s\n",
	$login ? "checked" : "", $text{'yes'};
printf "<input type=radio name=login value=0 %s> %s</td>\n",
	$login ? "" : "checked", $text{'no'};

$idle = &find("idle", \@opts);
print "<td><b>$text{'options_idle'}</b></td>\n";
printf "<td><input type=radio name=idle_def value=1 %s> %s\n",
	$idle ? "" : "checked", $text{'options_idle_def'};
printf "<input type=radio name=idle_def value=0 %s>\n",
	$idle ? "checked" : "";
printf "<input name=idle size=8 value='%s'> %s</td> </tr>\n",
	$idle->{'value'}, $text{'mgetty_secs'};

@dns = &find("ms-dns", \@opts);
print "<tr> <td><b>$text{'options_dns'}</b></td>\n";
printf "<td colspan=3><input name=dns size=50 value='%s'></td> </tr>\n",
	join(" ", map { $_->{'value'} } @dns);

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

if ($in{'file'}) {
	&ui_print_footer("list_mgetty.cgi", $text{'mgetty_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

