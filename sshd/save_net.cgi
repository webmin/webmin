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
		for($i=0; defined($in{"mode_$i"}); $i++) {
			next if ($in{"mode_$i"} == 0);
			if ($in{"mode_$i"} == 1) {
				$a = "0.0.0.0";
				}
			elsif ($in{"mode_$i"} == 2) {
				$a = "[::]";
				}
			elsif ($in{"mode_$i"} == 3) {
				$a = $in{"address_$i"};
				&check_ipaddress($a) || &check_ip6address($a) ||
					&error(&text('net_eladdress', $a));
				$a = "[$a]" if (&check_ip6address($a));
				}
			if ($in{"port_${i}_def"}) {
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
		  ($version{'number'} >= 2 && &to_ipaddress($in{'listen'})) ||
		    &error($text{'net_elisten'});
		&save_directive("ListenAddress", $conf, $in{'listen'});
		}
	}

# Save ports
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

# Sync socket options
&save_socket(\@ports, \@listens);

if ($version{'type'} eq 'openssh' &&
    $version{'number'} >= 2 && $version{'number'} < 7.6) {
	@prots = split(/\0/, $in{'prots'});
	@prots || &error($text{'net_eprots'});
	&save_directive("Protocol", $conf, join(",", @prots));
	}
elsif ($version{'number'} >= 7.6) {
	&save_directive("Protocol", $conf);
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

# Determine if the SSH version is 3.8 or higher
my $sshv38 = $version{'number'} >= 3.8;
my $keep_alive_key = $sshv38 ? 'TCPKeepAlive' : 'KeepAlive';
my $keep_curr = &find_value($keep_alive_key, $conf);
my $keep_now = $in{'keep'} ? 'yes' : 'no';
# Check if the current keep-alive value differs from the input value
if ($keep_curr ne $keep_now) {
    # Update the keep-alive value based on the input
    &save_directive($keep_alive_key, $conf, $keep_now);
    # Additional configuration for version 3.8 or higher
    if ($sshv38) {
        if ($keep_now eq 'yes') {
            # Enabled
            &save_directive('ClientAliveInterval', $conf, 60);
        } else {
            # Disabled
            &save_directive('ClientAliveInterval', $conf, 0);
        }
    }
}


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

