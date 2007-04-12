#!/usr/local/bin/perl
# edit_net.cgi
# Display networking related SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "", "net");
$conf = &get_sshd_config();

print "<form action=save_net.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'net_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	# Multiple listen addresses supported
	&scmd(1);
	@listens = &find("ListenAddress", $conf);
	print "<td valign=top><b>$text{'net_listen2'}</b></td>\n";
	print "<td colspan=3>\n";
	printf "<input type=radio name=listen_def value=1 %s> %s\n",
		@listens ? "" : "checked", $text{'net_listen_def'};
	printf "<input type=radio name=listen_def value=0 %s> %s<br>\n",
		@listens ? "checked" : "", $text{'net_below'};
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'net_laddress'}</b></td> ",
	      "<td><b>$text{'net_lport'}</b></td> </tr>\n";
	$i = 0;
	foreach $l (@listens, { }) {
		local ($a, $p) = $l->{'values'}->[0] =~ /^(.*):(\d+)$/ ?
				   ($1, $2) : ($l->{'values'}->[0]);
		print "<tr $cb>\n";
		print "<td><input name=address_$i size=25 value='$a'></td>\n";
		printf "<td><input type=radio name=port_def_$i value=1 %s> %s ",
			$p ? "" : "checked", $text{'default'};
		printf "<input type=radio name=port_def_$i value=0 %s>\n",
			$p ? "checked" : "";
		print "<input name=port_$i size=6 value='$p'></td>\n";
		print "</tr>\n";
		$i++;
		}
	print "</table>\n";
	&ecmd();
	}
else {
	# Just one listen address
	&scmd();
	$listen = &find_value("ListenAddress", $conf);
	$listen = "" if ($listen eq "0.0.0.0");
	print "<td><b>$text{'net_listen'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=listen_def value=1 %s> %s\n",
		$listen ? "" : "checked", $text{'net_listen_def'};
	printf "<input type=radio name=listen_def value=0 %s>\n",
		$listen ? "checked" : "";
	print "<input name=listen size=15 value='$listen'></td>\n";
	&ecmd();
	}

&scmd();
@ports = &find("Port", $conf);
$port = join(" ", map { $_->{'values'}->[0] } @ports);
print "<td><b>$text{'net_port'}</b></td> <td nowrap>\n";
printf "<input type=radio name=port_def value=1 %s> %s (22)\n",
	$port ? "" : "checked", $text{'default'};
printf "<input type=radio name=port_def value=0 %s>\n",
	$port ? "checked" : "";
print "<input name=port size=6 value='$port'></td>\n";
&ecmd();

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	&scmd();
	$prots = &find_value("Protocol", $conf);
	@prots = $prots ? split(/,/, $prots) :
		 $version{'number'} >= 2.9 ? (1, 2) : (1);
	print "<td><b>$text{'net_prots'}</b></td> <td>\n";
	foreach $p (1, 2) {
		printf "<input type=checkbox name=prots value=%s %s> %s\n",
			$p, &indexof($p, @prots) >= 0 ? "checked" : "",
			$text{"net_prots_$p"};
		}
	print "</td>\n";
	&ecmd();
	}

if ($version{'type'} eq 'ssh' &&
    ($version{'number'} < 2 || $version{'number'} >= 3)) {
	&scmd();
	$idle = &find_value("IdleTimeout", $conf);
	if ($idle =~ /^(\d+)([smhdw])$/i) {
		$idle = $1; $units = $2;
		}
	print "<td><b>$text{'net_idle'}</b></td> <td>\n";
	printf "<input type=radio name=idle_def value=1 %s> %s\n",
		$idle ? "" : "checked", $text{'default'};
	printf "<input type=radio name=idle_def value=0 %s>\n",
		$idle ? "checked" : "";
	print "<input name=idle size=6 value='$idle'>\n";
	print "<select name=idle_units>\n";
	foreach $u ('s', 'm', 'h', 'd', 'w') {
		printf "<option value=%s %s>%s\n",
			$u, $units eq $u ? 'selected' : '',
			$text{"net_idle_$u"};
		}
	print "</select></td>\n";
	&ecmd();
	}

&scmd();
$keep = &find_value("KeepAlive", $conf);
print "<td><b>$text{'net_keep'}</b></td> <td>\n";
printf "<input type=radio name=keep value=1 %s> %s\n",
	lc($keep) eq 'no' ? "" : "checked", $text{'yes'};
printf "<input type=radio name=keep value=0 %s> %s</td>\n",
	lc($keep) eq 'no' ? "checked" : "", $text{'no'};
&ecmd();

&scmd();
$grace = &find_value("LoginGraceTime", $conf);
print "<td><b>$text{'net_grace'}</b></td> <td>\n";
printf "<input type=radio name=grace_def value=1 %s> %s\n",
	$grace ? "" : "checked", $text{'net_grace_def'};
printf "<input type=radio name=grace_def value=0 %s>\n",
	$grace ? "checked" : "";
print "<input name=grace size=6 value='$grace'> $text{'net_grace_s'}</td>\n";
&ecmd();

if ($version{'type'} ne 'openssh' || $version{'number'} >= 2) {
	&scmd();
	$tcp = &find_value("AllowTcpForwarding", $conf);
	print "<td><b>$text{'net_tcp'}</b></td> <td>\n";
	printf "<input type=radio name=tcp value=1 %s> %s\n",
		lc($tcp) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=tcp value=0 %s> %s</td>\n",
		lc($tcp) eq 'no' ? "checked" : "", $text{'no'};
	&ecmd();
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	&scmd();
	$gateway = &find_value("GatewayPorts", $conf);
	print "<td><b>$text{'net_gateway'}</b></td> <td>\n";
	printf "<input type=radio name=gateway value=1 %s> %s\n",
		lc($gateway) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=gateway value=0 %s> %s</td>\n",
		lc($gateway) eq 'yes' ? "" : "checked", $text{'no'};
	&ecmd();

	if ($version{'number'} > 2.3 && $version{'number'} < 3.7) {
		&scmd();
		$reverse = &find_value("ReverseMappingCheck", $conf);
		print "<td><b>$text{'net_reverse'}</b></td> <td>\n";
		printf "<input type=radio name=reverse value=1 %s> %s\n",
			lc($reverse) eq 'yes' ? "checked" : "", $text{'yes'};
		printf "<input type=radio name=reverse value=0 %s> %s</td>\n",
			lc($reverse) eq 'yes' ? "" : "checked", $text{'no'};
		&ecmd();
		}
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

