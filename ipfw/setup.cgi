#!/usr/local/bin/perl
# setup.cgi
# Create an initial IPFW rules file

require './ipfw-lib.pl';
&ReadParse();

# Start with base configuration, which will include 65535 rule
$rules = &get_config("$config{'ipfw'} list |", \$out);
if ($in{'reset'}) {
	@$rules = grep { $_->{'num'} == 65535 } @$rules;
	}

# A flush will generate the 65535 rule, so we can exclude it
if (&get_ipfw_format() == 1) {
	@$rules = grep { $_->{'num'} != 65535 } @$rules;
	}

# Add selected rules
if ($in{'auto'} == 0) {
	# Allow all traffic
	splice(@$rules, 0, 0, { "action" => "allow",
				"num" => "00100",
				"proto" => "all",
				"from" => "any",
				"to" => "any",
				"cmt" => "Allow all traffic" });
	}
elsif ($in{'auto'} >= 2) {
	# Block all traffic, apart from established connections, DNS replies
	# and safe ICMP types
	$iface = $in{'iface'.$in{'auto'}} ||
		 $in{'iface'.$in{'auto'}.'_other'};
	$iface || &error($text{'setup_eiface'});
	splice(@$rules, 0, 0, { "action" => "skipto",
				"aarg" => "00300",
				"num" => "00100",
				"proto" => "all",
				"from" => "any",
				"to" => "any",
				"recv" => $iface,
				"cmt" => "Skip next rule for external interface" },
			      { "action" => "allow",
				"num" => "00200",
				"proto" => "all",
				"from" => "any",
				"to" => "any",
				"cmt" => "Allow all traffic on internal interfaces" },
			      { "action" => "allow",
				"num" => "00300",
				"proto" => "tcp",
				"from" => "any",
				"to" => "any",
				"established" => 1,
				"cmt" => "Allow established TCP connections" },
			      { "action" => "allow",
				"num" => "00400",
				"proto" => "tcp",
				"from" => "any",
				"to" => "any",
				"tcpflags" => "ack",
				"cmt" => "Allow traffic with ACK flag set" },
			      { "action" => "allow",
				"num" => "00500",
				"proto" => "udp",
				"from" => "any",
				"from_ports" => "53",
				"to" => "any",
				"to_ports" => "1024-65535",
				"cmt" => "Accept responses to DNS queries" },
			      { "action" => "allow",
				"num" => "00600",
				"proto" => "icmp",
				"from" => "any",
				"to" => "any",
				"icmptypes" => "0,3,4,11,12",
				"cmt" => "Accept safe ICMP types" });
	if ($in{'auto'} >= 3) {
		# Add SSH and ident
		splice(@$rules, @$rules-1, 0,
		      { "action" => "allow",
			"num" => "00700",
			"proto" => "tcp",
			"from" => "any",
			"to" => "any",
			"to_ports" => 22,
			"cmt" => "Allow connections to our SSH server" },
		      { "action" => "allow",
			"num" => "00800",
			"proto" => "tcp",
			"from" => "any",
			"to" => "any",
			"to_ports" => 113,
			"cmt" => "Allow connections to our IDENT server" });
		}
	if ($in{'auto'} >= 4) {
		# Allow pings and most high ports
		splice(@$rules, @$rules-1, 0,
			      { "action" => "allow",
				"num" => "00900",
				"proto" => "icmp",
				"from" => "any",
				"to" => "any",
				"icmptypes" => "8",
				"cmt" => "Respond to pings" },
			      { "action" => "deny",
				"num" => "01000",
				"proto" => "tcp",
				"from" => "any",
				"to" => "any",
				"to_ports" => "2049-2050",
				"cmt" => "Protect our NFS server" },
			      { "action" => "deny",
				"num" => "01100",
				"proto" => "tcp",
				"from" => "any",
				"to" => "any",
				"to_ports" => "6000-6063",
				"cmt" => "Protect our X11 display server" },
			      { "action" => "deny",
				"num" => "01200",
				"proto" => "tcp",
				"from" => "any",
				"to" => "any",
				"to_ports" => "7000-7010",
				"cmt" => "Protect our X font server" },
			      { "action" => "allow",
				"num" => "01300",
				"proto" => "tcp",
				"from" => "any",
				"to" => "any",
				"to_ports" => "1024-65535",
				"cmt" => "Allow connections to unprivileged ports" });
		}

	# Add final deny all rule (if needed)
	local $lr = $rules->[@$rules-1];
	if ($lr->{'num'} != 65535 || $lr->{'action'} ne 'deny') {
		splice(@$rules, @$rules-1, 0,
			      { "action" => "deny",
				"num" => "10000",
				"proto" => "all",
				"from" => "any",
				"to" => "any" });
		}
	}

# Add flush line at top
if (&get_ipfw_format() == 1) {
	splice(@$rules, 0, 0, { 'other' => 1,
				'text' => 'flush' });
	}

# Save firewall
&lock_file($ipfw_file);
&save_config($rules);
&unlock_file($ipfw_file);
&copy_to_cluster();

if ($in{'atboot'}) {
	&enable_boot();
	}

&webmin_log("setup");
&redirect("");

