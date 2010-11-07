#!/usr/local/bin/perl
# Enable or disable the iptables rule

require './frox-lib.pl';
&foreign_require("firewall", "firewall-lib.pl");
$conf = &get_config();
$port = &find_value("Port", $conf);
&error_setup($text{'iptables_err'});
&ReadParse();

# Validate inputs
if ($in{'enabled'} == 1) {
	&to_ipaddress($in{'net'}) ||
	    ($in{'net'} =~ /^([0-9\.]+)\/(\d+)$/ &&
	     &check_ipaddress($1) && $2 > 0 && $2 <= 32) ||
		&error($text{'iptables_enet'});
	}
elsif ($in{'enabled'} == 2) {
	$iface = $in{'iface'} eq 'other' ? $in{'iface_other'} : $in{'iface'};
	$iface =~ /^\S+$/ || &error($text{'iptables_eiface'});
	}

# Get the old rule
@tables = &firewall::get_iptables_save();
($nat) = grep { $_->{'name'} eq 'nat'} @tables;
if ($in{'rule'} ne "") {
	($rule) = $nat->{'rules'}->[$in{'rule'}];
	}

if ($in{'enabled'} && !$rule) {
	# Need to create
	$rule = { 'chain' => 'PREROUTING',
		  'j' => [ '', 'REDIRECT' ],
		  'p' => [ '', 'tcp' ],
		  'm' => [ '', 'tcp' ],
		  'dport' => [ '', 21 ],
		  'to-ports' => [ '', $port ],
		  ($iface ? ( 'i' => [ '', $iface ] )
			  : ( 's' => [ '', $in{'net'} ] ) ),
		  'cmt' => 'Forward FTP connections to Frox proxy' };
	push(@{$nat->{'rules'}}, $rule);
	$apply = 1;
	}
elsif ($in{'enabled'} && $rule) {
	# Need to update rule
	if ($iface) {
		delete($rule->{'s'});
		$rule->{'i'} = [ '', $iface ];
		}
	else {
		delete($rule->{'i'});
		$rule->{'s'} = [ '', $in{'net'} ];
		}
	$apply = 1;
	}
elsif (!$in{'enabled'} && $rule) {
	# Need to delete
	splice(@{$nat->{'rules'}}, $in{'rule'}, 1);
	$apply = 2;
	}
else {
	$apply = 0;
	}
if ($apply) {
	# Save and apply
	&lock_file($firewall::iptables_save_file);
	&firewall::save_table($nat);
	&unlock_file($firewall::iptables_save_file);
	$err = &firewall::apply_configuration();
	&error(&text('iptables_eapply', $err)) if ($err);
	&webmin_log("iptables", $apply);
	}

&redirect("");


