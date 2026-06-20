#!/usr/local/bin/perl
# save_aifc.cgi
# Save, create or delete an active interface

require './net-lib.pl';
&ReadParse();
@acts = &active_interfaces(1);

if ($in{'delete'}) {
	# delete an interface
	&error_setup($text{'aifc_err1'});
	$a = $acts[$in{'idx'}];
	&can_iface($a) || &error($text{'ifcs_ecannot_this'});
	&deactivate_interface($a);
	&webmin_log("delete", "aifc", $a->{'fullname'}, $a);
	}
else {
	# Validate and save inputs
	&error_setup($text{'aifc_err2'});
	if (!$in{'new'}) {
		# Editing existing interface
		$olda = $acts[$in{'idx'}];
		&can_iface($olda) || &error($text{'ifcs_ecannot_this'});
		$a->{'name'} = $olda->{'name'};
		$a->{'fullname'} = $olda->{'fullname'};
		$a->{'virtual'} = $olda->{'virtual'}
			if (defined($olda->{'virtual'}));
		}
	elsif (defined($in{'virtual'})) {
		# creating a virtual interface
		$in{'virtual'} =~ /^\d+$/ ||
			&error($text{'aifc_evirt'});
		$in{'virtual'} >= $min_virtual_number ||
			&error(&text('aifc_evirtmin', &html_escape($min_virtual_number)));
		foreach $ea (@acts) {
			if ($ea->{'name'} eq $in{'name'} &&
			    $ea->{'virtual'} eq $in{'virtual'}) {
				&error(&text('aifc_evirtdup',
				       &html_escape("$in{'name'}:$in{'virtual'}")));
				}
			}
		$a->{'name'} = $in{'name'};
		$a->{'virtual'} = $in{'virtual'};
		$a->{'fullname'} = $a->{'name'}.":".$a->{'virtual'};
		&can_create_iface() || &error($text{'ifcs_ecannot'});
		&can_iface($a) || &error($text{'ifcs_ecannot'});
		}
	elsif ($in{'name'} =~ /^([a-z]+\d*(s\d*)?(\.\d+)?):(\d+)$/) {
		# also creating a virtual interface
		foreach $ea (@acts) {
			if ($ea->{'name'} eq $1 &&
			    $ea->{'virtual'} eq $3) {
				&error(&text('aifc_evirtdup', &html_escape($in{'name'})));
				}
			}
		$3 >= $min_virtual_number ||
			&error(&text('aifc_evirtmin', &html_escape($min_virtual_number)));
		$a->{'name'} = $1;
		$a->{'virtual'} = $3;
		$a->{'fullname'} = $a->{'name'}.":".$a->{'virtual'};
		&can_create_iface() || &error($text{'ifcs_ecannot'});
		&can_iface($a) || &error($text{'ifcs_ecannot'});
		}
	elsif ($in{'name'} =~ /^[a-z]+\d*(s\d+)?(\.\d+)?$/) {
		# creating a real interface
		foreach $ea (@acts) {
			if ($ea->{'name'} eq $in{'name'}) {
				&error(&text('aifc_edup', &html_escape($in{'name'})));
				}
			}
		$a->{'name'} = $in{'name'};
		$a->{'fullname'} = $in{'name'};
		&can_create_iface() || &error($text{'ifcs_ecannot'});
		&can_iface($a) || &error($text{'ifcs_ecannot'});
		}
	else {
		&error($text{'aifc_ename'});
		}

	# Validate and store inputs
	&check_ipaddress_any($in{'address'}) ||
		&error(&text('aifc_eip', &html_escape($in{'address'})));
	$a->{'address'} = $in{'address'};

	# Check for address clash
	$allow_clash = defined(&allow_interface_clash) ?
			&allow_interface_clash($a, 0) : 1;
	if (!$allow_clash &&
	    ($in{'new'} || $olda->{'address'} ne $a->{'address'})) {
		($clash) = grep { $_->{'address'} eq $a->{'address'} } @acts;
		$clash && &error(&text('aifc_eclash', &html_escape($clash->{'fullname'})));
		}

	if ($virtual_netmask && $a->{'virtual'} ne "") {
		# Always use this netmask for virtuals
		$a->{'netmask'} = $virtual_netmask;
		}
	elsif (!$access{'netmask'}) {
		# Use default netmask
		$a->{'netmask'} = $in{'new'} ?
			$config{'def_netmask'} || "255.255.255.0" :
			$olda->{'netmask'};
		}
	elsif (!$in{'netmask_def'}) {
		&check_netmask($in{'netmask'},$a->{'address'}) ||
			&error(&text('aifc_emask', &html_escape($in{'netmask'})));
		$a->{'netmask'} = $in{'netmask'};
		}

	if (!$access{'broadcast'}) {
		# Compute broadcast
		$a->{'broadcast'} = $in{'new'} ?
			&compute_broadcast($a->{'address'}, $a->{'netmask'}) :
			$olda->{'broadcast'};
		}
	elsif (!$in{'broadcast_def'}) {
		&check_ipaddress_any($in{'broadcast'}) ||
			&error(&text('aifc_ebroad', &html_escape($in{'broadcast'})));
		$a->{'broadcast'} = $in{'broadcast'};
		}

	if (!$access{'mtu'}) {
		# Use default MTU
		$a->{'mtu'} = $in{'new'} ? $config{'def_mtu'}
					 : $olda->{'mtu'};
		}
	elsif (!$in{'mtu_def'}) {
		$in{'mtu'} =~ /^\d+$/ ||
			&error(&text('aifc_emtu', &html_escape($in{'mtu'})));
		$a->{'mtu'} = $in{'mtu'} if ($olda->{'mtu'} ne $in{'mtu'});
		}

	# Save active flag
	if (!$access{'up'}) {
		$a->{'up'} = $in{'new'} ? 1 : $olda->{'up'};
		}
	elsif ($in{'up'}) {
		$a->{'up'}++;
		}

	# Save IPv6 addresses
	if (&supports_address6($a) && $in{'mode6'} eq 'address') {
		# Has IPv6 addresses
		@address6 = ( );
		@netmask6 = ( );
		%clash6 = ( );
		foreach $eb (@acts) {
			if ($eb->{'fullname'} ne $a->{'fullname'}) {
				foreach $a6 (@{$eb->{'address6'}}) {
					$clash6{$a6} = $eb;
					}
				}
			}
		for($i=0; defined($in{'address6_'.$i}); $i++) {
			next if ($in{'address6_'.$i} !~ /\S/);
			&check_ip6address($in{'address6_'.$i}) ||
				&error(&text('aifc_eaddress6', $i+1));
			$c = $clash6{$in{'address6_'.$i}};
			$c && &error(&text('aifc_eclash6', $i+1, &html_escape($c->{'name'})));
			push(@address6, $in{'address6_'.$i});
			$in{'netmask6_'.$i} =~ /^\d+$/ &&
			    $in{'netmask6_'.$i} > 0 &&
			    $in{'netmask6_'.$i} <= 128 ||
				&error(&text('aifc_enetmask6', $i+1));
			push(@netmask6, $in{'netmask6_'.$i});
			$clash6{$in{'address6_'.$i}} = $a;
			}
		@address6 || &error($text{'aifc_eaddresses6'});
		$a->{'address6'} = \@address6;
		$a->{'netmask6'} = \@netmask6;
		}
	elsif (&supports_address6($a) && $in{'mode6'} eq 'none') {
		# IPv6 addresses disabled
		delete($a->{'address6'});
		delete($a->{'netmask6'});
		}

	if (!$in{'ether_def'} && $a->{'virtual'} eq "" &&
	    &iface_hardware($a->{'name'})) {
		$in{'ether'} =~ /^[A-Fa-f0-9:]+$/ ||
			&error(&text('aifc_ehard', &html_escape($in{'ether'})));
		$a->{'ether'} = $in{'ether'}
			if ($olda->{'ether'} ne $in{'ether'});
		}
	$a->{'fullname'} = $a->{'name'}.
			   ($a->{'virtual'} eq '' ? '' : ':'.$a->{'virtual'});

	# Bring it up
	&activate_interface($a);
	&webmin_log($in{'new'} ? 'create' : 'modify',
		    "aifc", $a->{'fullname'}, $a);
	}
&redirect("list_ifcs.cgi?mode=active");

