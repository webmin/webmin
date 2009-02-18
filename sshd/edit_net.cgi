#!/usr/local/bin/perl
# edit_net.cgi
# Display networking related SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "", "net");
$conf = &get_sshd_config();

print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, "width=100%", 2);

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	# Multiple listen addresses supported
	# XXX
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
	$listen = &find_value("ListenAddress", $conf);
	$listen = "" if ($listen eq "0.0.0.0");
	print &ui_table_row($text{'net_listen'},
		&ui_opt_textbox("listen", $listen, 20,$text{'net_listen_def'}));
	}

# Default port(s)
@ports = &find("Port", $conf);
$port = join(" ", map { $_->{'values'}->[0] } @ports);
print &ui_table_row($text{'net_port'},
	&ui_opt_textbox("port", $port, 15, $text{'default'}." (22)"));

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	# Protocols
	$prots = &find_value("Protocol", $conf);
	@prots = $prots ? split(/,/, $prots) :
		 $version{'number'} >= 2.9 ? (1, 2) : (1);
	$cbs = "";
	foreach $p (1, 2) {
		$cbs .= &ui_checkbox("prots", $p, &indexof($p, @prots) >= 0,
				     $text{"net_prots_$p"})." ";
		}
	print &ui_table_row($text{'net_prots'}, $cbs);
	}

if ($version{'type'} eq 'ssh' &&
    ($version{'number'} < 2 || $version{'number'} >= 3)) {
	# Idle connection timeout
	$idle = &find_value("IdleTimeout", $conf);
	if ($idle =~ /^(\d+)([smhdw])$/i) {
		$idle = $1; $units = $2;
		}
	print &ui_table_row($text{'net_idle'},
		&ui_radio("idle_def", $idle ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_textbox("idle", $idle", 6)." ".
			 &ui_select("idle_units", $units,
				[ map { [ $_, $text{"net_idle_".$_} ] }
				      ('s', 'm', 'h', 'd', 'w') ]) ] ]));
	}

# Send keepalive packets?
$keep = &find_value("KeepAlive", $conf);
print &ui_table_row($text{'net_keep'},
	&ui_yesno_radio("keep", lc($keep) ne 'no'));

# Grace time for logins
$grace = &find_value("LoginGraceTime", $conf);
print &ui_table_row($text{'net_grace'},
	&ui_opt_textbox("grace", $grace, 6, $text{'net_grace_def'})." ".
	$text{'net_grace_s'});

# XXX
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

