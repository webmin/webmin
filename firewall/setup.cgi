#!/usr/local/bin/perl
# setup.cgi
# Setup an initial save file

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'setup'} || &error($text{'setup_ecannot'});

&lock_file($ipvx_save);
if ($in{'reset'}) {
	# Clear out all rules
	foreach $t ("filter", "nat", "mangle") {
		&system_logged("iptables -t $t -P INPUT ACCEPT >/dev/null 2>&1");
		&system_logged("iptables -t $t -P OUTPUT ACCEPT >/dev/null 2>&1");
		&system_logged("iptables -t $t -P FORWARD ACCEPT >/dev/null 2>&1");
		&system_logged("iptables -t $t -P PREROUTING ACCEPT >/dev/null 2>&1");
		&system_logged("iptables -t $t -P POSTROUTING ACCEPT >/dev/null 2>&1");
		&system_logged("iptables -t $t -F >/dev/null 2>&1");
		&system_logged("iptables -t $t -X >/dev/null 2>&1");
		}
	}

# Save all existing active rules
if (defined(&unapply_iptables)) {
	&unapply_iptables();
	}
else {
	&backquote_logged("iptables-save >$ipvx_save 2>&1");
	}

# Get important variable ports
&get_miniserv_config(\%miniserv);
$webmin_port = $miniserv{'port'} || 10000;
$webmin_port2 = $webmin_port + 10;
$usermin_port = undef;
if (&foreign_installed("usermin")) {
	&foreign_require("usermin", "usermin-lib.pl");
	&usermin::get_usermin_miniserv_config(\%uminiserv);
	$usermin_port = $uminiserv{'port'};
	}
$usermin_port ||= 20000;
$ssh_port = undef;
if (&foreign_installed("sshd")) {
	&foreign_require("sshd", "sshd-lib.pl");
	$conf = &sshd::get_sshd_config();
	$ssh_port = &sshd::find_value("Port", $conf);
	}
$ssh_port ||= 22;

if ($in{'auto'}) {
	@tables = &get_iptables_save();
	if ($in{'auto'} == 1) {
		# Add a single rule to the nat table for masquerading
		$iface = $in{'iface1'} eq 'other' ? $in{'iface1_other'}
						  : $in{'iface1'};
		$iface || &error($text{'setup_eiface'});
		($table) = grep { $_->{'name'} eq 'nat' } @tables;
		$table ||= { 'name' => 'nat',
			     'rules' => [ ],
			     'defaults' => { } };
		push(@{$table->{'rules'}},
		     	{ 'chain' => 'POSTROUTING',
			  'o' => [ "", $iface ],
			  'j' => [ "", 'MASQUERADE' ] } );
		}
	elsif ($in{'auto'} >= 2) {
		# Block all incoming traffic, except for established
		# connections, DNS replies and safe ICMP types
		# In mode 3 allow ssh and ident too
		# In mode 4 allow ftp, echo-request and high ports too
		$iface = $in{'iface'.$in{'auto'}} eq 'other' ?
				 $in{'iface'.$in{'auto'}.'_other'} :
				 $in{'iface'.$in{'auto'}};
		$iface || &error($text{'setup_eiface'});
		($table) = grep { $_->{'name'} eq 'filter' } @tables;
		$table ||= { 'name' => 'nat',
			     'rules' => [ ],
			     'defaults' => { } };
		$table->{'defaults'}->{'INPUT'} = 'DROP';
		push(@{$table->{'rules'}},
		     { 'chain' => 'INPUT',
		       'i' => [ "!", $iface ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept traffic from internal interfaces' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "tcp" ] ],
		       'p' => [ "", "tcp" ],
		       'tcp-flags' => [ "", "ACK", "ACK" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept traffic with the ACK flag set' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "state" ] ],
		       'state' => [ "", "ESTABLISHED" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Allow incoming data that is part of a connection we established' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "state" ] ],
		       'state' => [ "", "RELATED" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Allow data that is related to existing connections' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "udp" ] ],
		       'p' => [ "", "udp" ],
		       'sport' => [ "", 53 ],
		       'dport' => [ "", "1024:65535" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept responses to DNS queries' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "icmp" ] ],
		       'p' => [ [ "", "icmp" ] ],
		       'icmp-type' => [ "", "echo-reply" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept responses to our pings' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "icmp" ] ],
		       'p' => [ [ "", "icmp" ] ],
		       'icmp-type' => [ "", "destination-unreachable" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept notifications of unreachable hosts' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "icmp" ] ],
		       'p' => [ [ "", "icmp" ] ],
		       'icmp-type' => [ "", "source-quench" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept notifications to reduce sending speed' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "icmp" ] ],
		       'p' => [ [ "", "icmp" ] ],
		       'icmp-type' => [ "", "time-exceeded" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept notifications of lost packets' },
		     { 'chain' => 'INPUT',
		       'm' => [ [ "", "icmp" ] ],
		       'p' => [ [ "", "icmp" ] ],
		       'icmp-type' => [ "", "parameter-problem" ],
		       'j' => [ "", 'ACCEPT' ],
		       'cmt' => 'Accept notifications of protocol problems' }
			);
		if ($in{'auto'} >= 3) {
			# Allow ssh and ident
			push(@{$table->{'rules'}},
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", $ssh_port ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to our SSH server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "auth" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to our IDENT server'}
				);
			}
		if ($in{'auto'} >= 4) {
			# Allow pings
			push(@{$table->{'rules'}},
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "icmp" ] ],
			       'p' => [ [ "", "icmp" ] ],
			       'icmp-type' => [ "", "echo-request" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Respond to pings' }, );
			}
		if ($in{'auto'} == 4) {
			# Allow pings and most high ports
			push(@{$table->{'rules'}},
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "2049:2050" ],
			       'j' => [ "", 'DROP' ],
			       'cmt' => 'Protect our NFS server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "6000:6063" ],
			       'j' => [ "", 'DROP' ],
			       'cmt' => 'Protect our X11 display server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "7000:7010" ],
			       'j' => [ "", 'DROP' ],
			       'cmt' => 'Protect our X font server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "1024:65535" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to unprivileged ports' },
				);
			}
		if ($in{'auto'} == 5) {
			# Allow typical hosting server ports
			push(@{$table->{'rules'}},
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "53" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow DNS zone transfers' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "udp" ] ],
			       'p' => [ "", "udp" ],
			       'dport' => [ "", "53" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow DNS queries' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "80" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to webserver' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "443" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow SSL connections to webserver' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ], [ "", "multiport" ] ],
			       'p' => [ "", "tcp" ],
			       'dports' => [ "", "25,587" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to mail server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", "20:21" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to FTP server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ], [ "", "multiport" ] ],
			       'p' => [ "", "tcp" ],
			       'dports' => [ "", "110,995" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to POP3 server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ], [ "", "multiport" ] ],
			       'p' => [ "", "tcp" ],
			       'dports' => [ "", "143,220,993" ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to IMAP server' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "",$webmin_port.":".$webmin_port2 ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to Webmin' },
			     { 'chain' => 'INPUT',
			       'm' => [ [ "", "tcp" ] ],
			       'p' => [ "", "tcp" ],
			       'dport' => [ "", $usermin_port ],
			       'j' => [ "", 'ACCEPT' ],
			       'cmt' => 'Allow connections to Usermin' },
				);
			}
		}
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	}

if ($in{'atboot'}) {
	&create_firewall_init();
	}
&unlock_file($ipvx_save);

&webmin_log("setup");
&redirect("");


