#!/usr/local/bin/perl
# save_net.cgi
# save networking sshd options

require './sshd-lib.pl';
&ReadParse();
&error_setup($text{'net_err'});
&lock_file($config{'sshd_config'});
$conf = &get_sshd_config();

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	# Save multiple
	if ($in{'listen_def'}) {
		&save_directive("ListenAddress", $conf);
		}
	else {
		for($i=0; defined($a = $in{"address_$i"}); $i++) {
			next if (!$a);
			&check_ipaddress($a) || gethostbyname($a) ||
				&error(&text('net_eladdress', $a));
			if ($in{"port_def_$i"}) {
				push(@listens, $a);
				}
			else {
				$in{"port_$i"} =~ /^\d+$/ ||
				    &error(&text('net_elport', $in{"port_$i"}));
				push(@listens, $a.":".$in{"port_$i"});
				}
			}
		@listens || &error($text{'net_elisten2'});
		&save_directive("ListenAddress", $conf, @listens);
		}
	}
else {
	# Save just one address
	if ($in{'listen_def'}) {
		&save_directive("ListenAddress", $conf);
		}
	else {
		&check_ipaddress($in{'listen'}) ||
		  ($version{'number'} >= 2 && gethostbyname($in{'listen'})) ||
		    &error($text{'net_elisten'});
		&save_directive("ListenAddress", $conf, $in{'listen'});
		}
	}

if ($in{'port_def'}) {
	&save_directive("Port", $conf);
	}
else {
	@ports = split(/\s+/, $in{'port'});
	@ports || &error($text{'net_eport'});
	foreach $p (@ports) {
		$p =~ /^\d+$/ || &error($text{'net_eport'});
		}
	&save_directive("Port", $conf, \@ports, "ListenAddress");
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	@prots = split(/\0/, $in{'prots'});
	@prots || &error($text{'net_eprots'});
	&save_directive("Protocol", $conf, join(",", @prots));
	}

if ($version{'type'} eq 'ssh' &&
    ($version{'number'} < 2 || $version{'number'} >= 3)) {
	if ($in{'idle_def'}) {
		&save_directive("IdleTimeout", $conf);
		}
	else {
		$in{'idle'} =~ /^\d+$/ || &error($text{'net_eidle'});
		&save_directive("IdleTimeout", $conf,
				$in{'idle'}.$in{'idle_units'});
		}
	}

&save_directive("KeepAlive", $conf, $in{'keep'} ? 'yes' : 'no');

if ($in{'grace_def'}) {
	&save_directive("LoginGraceTime", $conf);
	}
else {
	$in{'grace'} =~ /^\d+$/ || &error($text{'net_egrace'});
	&save_directive("LoginGraceTime", $conf, $in{'grace'});
	}

if ($version{'type'} ne 'openssh' || $version{'number'} >= 2) {
	&save_directive("AllowTcpForwarding", $conf, $in{'tcp'} ? 'yes' : 'no');
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	&save_directive("GatewayPorts", $conf, $in{'gateway'} ? 'yes' : 'no');

	if ($version{'number'} > 2.3 && $version{'number'} < 3.7) {
		&save_directive("ReverseMappingCheck", $conf,
				$in{'reverse'} ? 'yes' : 'no');
		}
	}

&flush_file_lines();
&unlock_file($config{'sshd_config'});
&webmin_log("net");
&redirect("");

