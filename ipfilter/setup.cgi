#!/usr/local/bin/perl
# setup.cgi
# Setup an initial save file

require './ipfilter-lib.pl';
&ReadParse();

@rules = ( );
if ($in{'auto'}) {
	$iface = $in{'iface'.$in{'auto'}};
	if ($iface eq 'other') {
		$iface = $in{'iface'.$in{'auto'}.'_other'};
		}
	$iface || &error($text{'setup_eiface'});
	if ($in{'auto'} >= 2) {
		# Block all incoming traffic, except for established
		# connections, DNS replies and safe ICMP types
		# In mode 3 allow ssh and ident too
		# In mode 4 allow ftp, echo-request and high ports too
		push(@rules,
		     { 'action' => 'skip', 'skip' => 1, 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'all' => 1,
		       'on' => $iface,
		       'cmt' => 'Skip next rule for external interface' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'all' => 1,
		       'keep' => 'state',
		       'cmt' => 'Allow all traffic on internal interface' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'proto' => 'udp',
		       'from-any' => 1,
		       'to-any' => 1,
		       'to-port-start' => 1024,
		       'to-port-range' => '<>',
		       'to-port-end' => 1024,
		       'keep' => 'state',
		       'cmt' => 'Accept responses to DNS queries' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'proto' => 'icmp',
		       'all' => 1,
		       'icmp-type' => 'echorep',
		       'keep' => 'state',
		       'cmt' => 'Accept responses to our pings' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'proto' => 'icmp',
		       'all' => 1,
		       'icmp-type' => 'unreach',
		       'keep' => 'state',
		       'cmt' => 'Accept notifications of unreachable hosts' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'proto' => 'icmp',
		       'all' => 1,
		       'icmp-type' => 'squench',
		       'keep' => 'state',
		       'cmt' => 'Accept notifications to reduce sending speed' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'proto' => 'icmp',
		       'all' => 1,
		       'icmp-type' => 'timex',
		       'keep' => 'state',
		       'cmt' => 'Accept notifications of lost packets' },
		     { 'action' => 'pass', 'active' => 1,
		       'quick' => 1, 'dir' => 'in',
		       'proto' => 'icmp',
		       'all' => 1,
		       'icmp-type' => 'paramprob',
		       'keep' => 'state',
		       'cmt' => 'Accept notifications of protocol problems' }
			);
		if ($in{'auto'} >= 3) {
			# Allow ssh and ident
			push(@rules,
			     { 'action' => 'pass', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'tcp',
			       'from-any' => 1,
			       'to-any' => 1,
			       'to-port-comp' => '=',
			       'to-port-num' => 22,
			       'keep' => 'state',
			       'cmt' => 'Allow connections to our SSH server' },
			     { 'action' => 'pass', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'tcp',
			       'from-any' => 1,
			       'to-any' => 1,
			       'to-port-comp' => '=',
			       'to-port-num' => 113,
			       'keep' => 'state',
			       'cmt' => 'Allow connections to our IDENT server' },
				);
			}
		if ($in{'auto'} == 4) {
			# Allow pings and most high ports
			push(@rules,
			     { 'action' => 'pass', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'icmp',
			       'all' => 1,
			       'icmp-type' => 'echo',
			       'keep' => 'state',
			       'cmt' => 'Respond to pings' },
			     { 'action' => 'block', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'tcp',
			       'from-any' => 1,
			       'to-any' => 1,
			       'to-port-start' => 2049,
			       'to-port-range' => '<>',
			       'to-port-end' => 2050,
			       'keep' => 'state',
			       'cmt' => 'Protect our NFS server' },
			     { 'action' => 'block', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'tcp',
			       'from-any' => 1,
			       'to-any' => 1,
			       'to-port-start' => 6000,
			       'to-port-range' => '<>',
			       'to-port-end' => 6063,
			       'keep' => 'state',
			       'cmt' => 'Protect our X11 display server' },
			     { 'action' => 'block', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'tcp',
			       'from-any' => 1,
			       'to-any' => 1,
			       'to-port-start' => 7000,
			       'to-port-range' => '<>',
			       'to-port-end' => 7010,
			       'keep' => 'state',
			       'cmt' => 'Protect our X font server' },
			     { 'action' => 'pass', 'active' => 1,
			       'quick' => 1, 'dir' => 'in',
			       'proto' => 'tcp',
			       'from-any' => 1,
			       'to-any' => 1,
			       'to-port-start' => 1024,
			       'to-port-range' => '<>',
			       'to-port-end' => 65535,
			       'keep' => 'state',
			       'cmt' => 'Allow connections to unprivileged ports' },
				);
			}

		# Add final block rule
		push(@rules, { 'action' => 'block', 'active' => 1,
			       'all' => 1,
			       'dir' => 'in' });
		push(@rules, { 'action' => 'pass', 'active' => 1,
			       'all' => 1,
			       'dir' => 'out' });
		}
	else {
		# Just add one rule for NAT
		push(@natrules, { 'action' => 'map', 'active' => 1,
				  'fromip' => '0.0.0.0', 'frommask' => 0,
				  'toip' => '0.0.0.0', 'tomask' => 32,
				  'iface' => $iface,
				  'type' => 'ipnat' });

		# Allow all other traffic
		push(@rules, { 'action' => 'pass', 'active' => 1,
			       'all' => 1,
			       'dir' => 'in' });
		push(@rules, { 'action' => 'pass', 'active' => 1,
			       'all' => 1,
			       'dir' => 'out' });
		}
	}
else {
	# Just add rules to allow all
	push(@rules, { 'action' => 'pass', 'active' => 1,
		       'all' => 1,
		       'dir' => 'in' });
	push(@rules, { 'action' => 'pass', 'active' => 1,
		       'all' => 1,
		       'dir' => 'out' });
	}
&lock_file($config{'ipf_conf'});
&save_config(\@rules);
&unlock_file($config{'ipf_conf'});
&lock_file($config{'ipnatf_conf'});
&save_config(\@natrules, undef, 'ipnat');
&unlock_file($config{'ipnatf_conf'});
&copy_to_cluster();

if ($in{'atboot'}) {
	&create_firewall_init();
	}

&webmin_log("setup");
&redirect("");


