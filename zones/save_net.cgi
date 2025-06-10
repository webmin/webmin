#!/usr/local/bin/perl
# Update, add or delete a network interface

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});
if (!$in{'new'}) {
	# Find the network object
	($net) = grep { $_->{'address'} eq $in{'old'} } @{$zinfo->{'net'}};
	$net || &error($text{'net_egone'});
	$active = &get_active_interface($zinfo, $net);
	}
$net ||= { 'keytype' => 'net' };

if ($in{'delete'}) {
	# Just remove this network
	&delete_zone_object($zinfo, $net);
	&net::deactivate_interface($active) if ($active);
	}
else {
	# Validate inputs
	$form = &get_net_form(\%in, $zinfo, $net);
	$form->validate_redirect("edit_net.cgi");
	if ($form->get_value("netmask")) {
		$cidr = &net::mask_to_prefix($form->get_value("netmask"));
		$net->{'address'} = $form->get_value("address")."/".$cidr;
		}
	else {
		$net->{'address'} = $form->get_value("address");
		}
	$net->{'physical'} = $form->get_value("physical");
	&find_clash($zinfo, $net) &&
		$form->validate_redirect("edit_net.cgi",
					[ [ "address", $text{'net_eclash'} ] ]);

	# Create or update the real interface
	if ($in{'new'}) {
		local $vmax = int($net::min_virtual_number);
		local $a;
		foreach $a (&net::active_interfaces()) {
			$vmax = $a->{'virtual'}
				if ($a->{'name'} eq $in{'physical'} &&
				    $a->{'virtual'} > $vmax);
			}
		$active = { 'name' => $in{'physical'},
			    'virtual' => $vmax+1,
			    'fullname' => $in{'physical'}.":".($vmax+1),
			    'zone' => $in{'zone'},
			    'up' => 1 };
		}
	if ($active) {
		$active->{'address'} = $in{'address'};
		if ($in{'netmask_def'}) {
			$active->{'netmask'} =
				&net::automatic_netmask($in{'address'});
			}
		else {
			$active->{'netmask'} = $in{'netmask'};
			}
		$active->{'broadcast'} = &net::compute_broadcast(
			$active->{'address'}, $active->{'netmask'});
		$active->{'zone'} = $in{'zone'};
		}

	# Save the zone settings
	if ($in{'new'}) {
		&create_zone_object($zinfo, $net);
		if ($zinfo->{'status'} eq 'running') {
			&net::activate_interface($active);
			}
		}
	else {
		&modify_zone_object($zinfo, $net);
		if ($active) {
			&net::activate_interface($active);
			}
		}
	}

&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "net", $in{'old'} || $net->{'address'}, $net);
&redirect("edit_zone.cgi?zone=$in{'zone'}");

