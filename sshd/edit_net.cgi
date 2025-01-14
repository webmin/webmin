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
	@listens = &find("ListenAddress", $conf);
	$i = 0;
	@table = ( );
	foreach $l (@listens, { }) {
		local ($a, $p) = $l->{'values'}->[0] =~ /^([^:]*):(\d+)$/ ||
				 $l->{'values'}->[0] =~ /^\[(.*)\]:(\d+)$/ ?
				   ($1, $2) :
				 $l->{'values'}->[0] =~ /^\[(.*)\]$/ ?
				   ($1) :
				   ($l->{'values'}->[0]);
		$amode = $a eq "::" ? 2 : $a eq "0.0.0.0" ? 1 :
			 $a eq "" ? 0 : 3;
		push(@table, [
			&ui_select("mode_$i", $amode,
				   [ [ 0, "&nbsp;" ],
				     [ 1, $text{'net_all4'} ],
				     [ 2, $text{'net_all6'} ],
				     [ 3, $text{'net_sel'} ] ])." ".
			&ui_textbox("address_$i", $amode == 3 ? $a : "", 25),
			&ui_opt_textbox("port_$i", $p, 6, $text{'default'})
			]);
		$i++;
		}
	print &ui_table_row($text{'net_listen2'},
		&ui_radio("listen_def", @listens ? 0 : 1,
			  [ [ 1, $text{'net_listen_def'} ],
			    [ 0, $text{'net_below'} ] ])."<br>\n".
		&ui_columns_table([ $text{'net_laddress'},
				    $text{'net_lport'} ],
				  undef, \@table));
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
	my @prots_avail = (1, 2);
	if ($version{'number'} < 2 || $version{'number'} >= 7.6) {
		# Since SSH-1 is removed in 7.6, displaying the protocol is
		# unnecessary because only SSH-2 protocol is available.
		# Protocol directive is ignored even if set
		@prots_avail = ();
		}
	if (@prots_avail) {
		my $prots = &find_value("Protocol", $conf);
		my @prots = $prots ? split(/,/, $prots) : @prots_avail;
		my $cbs = "";
		foreach $p (1, 2) {
			$cbs .= &ui_checkbox("prots", $p, $text{"net_prots_$p"},
					     &indexof($p, @prots) >= 0)." ";
			}
		print &ui_table_row($text{'net_prots'}, $cbs);
		}
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
		    [ 0, &ui_textbox("idle", $idle, 6)." ".
			 &ui_select("idle_units", $units,
				[ map { [ $_, $text{"net_idle_".$_} ] }
				      ('s', 'm', 'h', 'd', 'w') ]) ] ]));
	}

# Send keepalive packets?
$keep = &find_value($version{'number'} >= 3.8 ? 'TCPKeepAlive' : 'KeepAlive',
		    $conf);
print &ui_table_row($text{'net_keep'},
	&ui_yesno_radio("keep", $version{'number'} >= 3.8 ?
		# Defaults to 'No'   Defaults to 'Yes'
		lc($keep) eq 'yes' : lc($keep) ne 'no'));

# Grace time for logins
$grace = &find_value("LoginGraceTime", $conf);
print &ui_table_row($text{'net_grace'},
	&ui_opt_textbox("grace", $grace, 6, $text{'net_grace_def'})." ".
	$text{'net_grace_s'});

if ($version{'type'} ne 'openssh' || $version{'number'} >= 2) {
	# Allow port forwarding?
	$tcp = &find_value("AllowTcpForwarding", $conf);
	print &ui_table_row($text{'net_tcp'},
		&ui_yesno_radio("tcp", lc($tcp) ne 'no'));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	# Allow connections to forwarded ports
	$gateway = &find_value("GatewayPorts", $conf);
	print &ui_table_row($text{'net_gateway'},
		&ui_yesno_radio("gateway", lc($gateway) eq 'yes'));

	if ($version{'number'} > 2.3 && $version{'number'} < 3.7) {
		# Validate reverse IP
		$reverse = &find_value("ReverseMappingCheck", $conf);
		print &ui_table_row($text{'net_reverse'},
			&ui_yesno_radio("reverse", lc($reverse) eq 'yes'));
		}
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

