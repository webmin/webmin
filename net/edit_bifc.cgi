#!/usr/local/bin/perl
# edit_bifc.cgi
# Edit or create a bootup interface

require './net-lib.pl';
&ReadParse();
!$in{'new'} || &can_create_iface() || &error($text{'ifcs_ecannot'});

# Show page title
if ($in{'new'} && $in{'bond'}) {
	&ui_print_header(undef, $text{'bonding_create'}, "");
	}
elsif ($in{'new'} && $in{'vlan'}) {
	&ui_print_header(undef, $text{'vlan_create'}, "");
	}
elsif ($in{'new'}) {
	&ui_print_header(undef, $text{'bifc_create'}, "");
	}
else {
	@boot = &boot_interfaces();
	$b = $boot[$in{'idx'}];
	&can_iface($b) || &error($text{'ifcs_ecannot_this'});
	&ui_print_header(undef, $text{'bifc_edit'}, "");
	}

# Start of the form
print &ui_form_start("save_bifc.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("vlan", $in{'vlan'});
print &ui_hidden("bond", $in{'bond'});
print &ui_table_start($in{'virtual'} || $b && $b->{'virtual'} ne "" ?
			$text{'bifc_desc2'} : $text{'bifc_desc1'},
		      "width=100%", 4);

# Comment, if allowed
if (defined(&can_iface_desc) && &can_iface_desc($b)) {
	print &ui_table_row($text{'ifcs_desc'},
		&ui_textbox("desc", $b ? $b->{'desc'} : undef, 60), 3);
	}

# Interface name
if ($in{'new'} && $in{'virtual'}) {
	# New virtual interface
	$namefield = $in{'virtual'}.":".&ui_textbox("virtual", undef, 3).
		     &ui_hidden("name", $in{'virtual'});
	}
elsif ($in{'new'}) {
	# New real interface
	if ($in{'vlan'} == 1) {
		$namefield = "auto".&ui_hidden("name", "auto");
		}
	else {
		$namefield = &ui_textbox("name", undef, 6);
		}
	}
else {
	# Existing interface
	$namefield = "<tt>$b->{'fullname'}</tt>";
	}
print &ui_table_row($text{'ifcs_name'}, $namefield);

# Activate at boot?
if (&can_edit("up", $b) && $access{'up'}) {
	$upfield = &ui_yesno_radio("up", !$b || $b->{'up'});
	}
else {
	$upfield = !$b ? $text{'yes'} :
		   $b->{'up'} ? $text{'yes'} : $text{'no'};
	}
print &ui_table_row($text{'ifcs_act'}, $upfield);

# IP address source. This can either be DHCP, BootP or a fixed IP,
# netmask and broadcast
$virtual = (!$b && $in{'virtual'}) || ($b && $b->{'virtual'} ne "");
$dhcp = &can_edit("dhcp") && !$virtual;
$bootp = &can_edit("bootp") && !$virtual;
@opts = ( );
if ($dhcp) {
	push(@opts, [ "dhcp", $text{'ifcs_dhcp'} ]);
	}
if ($bootp) {
	push(@opts, [ "bootp", $text{'ifcs_bootp'} ]);
	}
@grid = ( $text{'ifcs_ip'}, &ui_textbox("address", $b->{'address'}, 15) );
if ($in{'virtual'} && $in{'new'} && $virtual_netmask) {
	# Netmask is fixed
	push(@grid, $text{'ifcs_mask'}, "<tt>$virtual_netmask</tt>");
	}
elsif (&can_edit("netmask", $b) && $access{'netmask'}) {
	# Can edit netmask
	push(@grid, $text{'ifcs_mask'},
		    &ui_textbox("netmask", $b ? $b->{'netmask'}
					      : $config{'def_netmask'}, 15));
	}
elsif ($b && $b->{'netmask'}) {
	# Cannot edit
	push(@grid, $text{'ifcs_mask'}, "<tt>$b->{'netmask'}</tt>");
	}
if (!$b || !&is_ipv6_address($b->{'address'})){
	if (&can_edit("broadcast", $b) && $access{'broadcast'}) {
		# Can edit broadcast address
		push(@grid, $text{'ifcs_broad'},
		    &ui_textbox("broadcast", $b ? $b->{'broadcast'}
						: $config{'def_broadcast'},15));
		}
	elsif ($b && $b->{'broadcast'}) {
		# Broadcast is fixed
		push(@grid, $text{'ifcs_broad'}, "<tt>$b->{'broadcast'}</tt>");
		}
	}
push(@opts, [ "address", $text{'ifcs_static2'}, &ui_grid_table(\@grid, 2) ]);

# Show the IP field
if (@opts > 1) {
	print &ui_table_row($text{'ifcs_mode'},
		&ui_radio_table("mode", $b && $b->{'dhcp'} ? "dhcp" :
					$b && $b->{'bootp'} ? "bootp" :
							      "address",
				\@opts));
	}
else {
	print &ui_table_row($opts[0]->[1], $opts[0]->[2]);
	}

# MTU
if (&can_edit("mtu", $b) && $access{'mtu'}) {
	$mtufield = &ui_textbox("mtu", $b ? $b->{'mtu'} : $config{'def_mtu'},8);
	}
else {
	$mtufield = $b && $b->{'mtu'} ? $b->{'mtu'} : undef;
	}
if ($mtufield) {
	print &ui_table_row($text{'ifcs_mtu'}, $mtufield);
	}

# Virtual sub-interfaces
if ($b && $b->{'virtual'} eq "") {
	$vcount = 0;
	foreach $vb (@boot) {
		if ($vb->{'virtual'} ne "" && $vb->{'name'} eq $b->{'name'}) {
			$vcount++;
			}
		}
	$vlink = "";
	if ($access{'virt'} && !$noos_support_add_virtifcs) {
		$vlink = "(<a href='edit_bifc.cgi?new=1&virtual=$b->{'name'}'>".
		         "$text{'ifcs_addvirt'}</a>)\n";
		}
	print &ui_table_row($text{'ifcs_virts'}, $vcount." ".$vlink);
	}

# Special parameters for teaming
print "<tr>\n";
if($in{'bond'} or (&iface_type($b->{'name'}) eq 'Bonded')) {		
	# Select bonding teampartner
	print "<td><b>$text{'bonding_teamparts'}</b></td>\n";
	print "<td>\n";
	print "<input type='text' name='partner' value='$b->{'partner'}' />";
	print "</td>\n";
	
	@mode = ("balance-rr", "activebackup", "balance-xor", "broadcast", "802.3ad", "balance-tlb", "balance-alb");
	
	# Select teaming mode
	print "<td><b>$text{'bonding_teammode'}</b></td>\n";
	print "<td>\n";
	print "<select name=bondmode>\n";
	for ($i = 0; $i < 7; $i++){
		print "<option value=\"$i\"";
		
		if($i == $b->{'mode'}){
			print " selected=true";
		} 
		
		print ">\n";
		print $mode[$i];
		print "</option>\n";
	}
	print "</select>\n";
	print "</td>\n";
	print "<tr>\n";

	# Select mii Monitoring Interval
	print "<td><b>$text{'bonding_miimon'}</b></td>\n";
	print "<td>\n";
	print "<input type=\"text\" name=\"miimon\" value=\"" . $b->{'miimon'} . "\"/> ms\n";
	print "</td>\n";

	# Select updelay
	print "<td><b>$text{'bonding_updelay'}</b></td>\n";
	print "<td>\n";
	print "<input type=\"text\" name=\"updelay\" value=\"" . $b->{'updelay'} . "\" /> ms\n";
	print "</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	# Select downdelay
	print "<td><b>$text{'bonding_downdelay'}</b></td>\n";
	print "<td>\n";
	print "<input type=\"text\" name=\"downdelay\" value=\"" . $b->{'downdelay'} . "\" /> ms\n";
	print "</td>\n";
}
print "</tr>\n";


# Special Parameter for vlan tagging
if(($in{'vlan'}) or (&iface_type($b->{'name'}) =~ /^(.*) (VLAN)$/)) {
	$b->{'name'} =~ /(\S+)\.(\d+)/;
	
	$physical = $1;
	$vlanid = $2;

	print "<tr>\n";
	print "<td><b>$text{'vlan_physical'}</b></td>\n";
	print "<td>\n";
	
	if(!$in{'new'}) {
		print "$physical";
		print "<input type='hidden' name='physical' value='$physical' />\n";
	} else {
		print "<select name='physical' size='1'>"; 
	
		@interfaces = &list_interfaces();
		foreach $if (@interfaces) {
			if(!($if eq $b->{'name'})){
				print "<option";
				if($if eq $physical) {
					print " selected='true'";
				} 
				print ">" . $if . "</option>\n";
			}
		}
		print "</select>";
	}
	print "</td>\n";
	
	print "<td><b>VLAN-ID</b></td>\n";
	print "<td>\n";
	
	if(!$in{'new'}) {
		print "$vlanid";
		print "<input type='hidden' name='vlanid' value='$vlanid' />\n";
	} else {
		print "<input type='text' name='vlanid' value='$vlanid' ";	
	}
	print "</td>\n";
	
	print "</tr>\n";
}

print &ui_table_end();
     
# Generate and show buttons at end of the form
@buts = ( );
if ($access{'bootonly'}) {
	# Can only save both boot-time and active
	if ($in{'new'}) {
		push(@buts, [ "activate", $text{'bifc_capply'} ]);
		}
	else {
		push(@buts, [ "activate", $text{'bifc_apply'} ]);
		if ($access{'delete'}) {
			push(@buts, [ "unapply", $text{'bifc_dapply'} ]);
			}
		}
	}
else {
	# Show buttons to save both boot-time and/or active
	if ($in{'new'}) {
		push(@buts, [ undef, $text{'create'} ]);
		push(@buts, [ "activate", $text{'bifc_capply'} ]);
		}
	else {
		push(@buts, [ undef, $text{'save'} ])
			unless $always_apply_ifcs;
		if (!($b->{'bootp'} || $b->{'dhcp'}) ||
		    defined(&apply_interface)) {
			push(@buts, [ "activate", $text{'bifc_apply'} ]);
			}
		if ($access{'delete'}) {
			push(@buts, [ "unapply", $text{'bifc_dapply'} ]);
			push(@buts, [ "delete", $text{'delete'} ])
				unless $noos_support_delete_ifcs;
			}
		}
	}
print &ui_form_end(\@buts);

&ui_print_footer("list_ifcs.cgi?mode=boot", $text{'ifcs_return'});

