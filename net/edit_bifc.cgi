#!/usr/local/bin/perl
# edit_bifc.cgi
# Edit or create a bootup interface

require './net-lib.pl';
&ReadParse();
if ($in{'new' && $in{'bonding'}}) {
	&ui_print_header(undef, $text{'bifc_create'}, "");
	&can_create_iface() || &error($text{'ifcs_ecannot'});
	}
elsif ($in{'new'}) {
	&ui_print_header(undef, $text{'vlan_create'}, "");
	&can_create_iface() || &error($text{'ifcs_ecannot'});
	}

else {
	@boot = &boot_interfaces();
	$b = $boot[$in{'idx'}];
	&can_iface($b) || &error($text{'ifcs_ecannot_this'});
	&ui_print_header(undef, $text{'bifc_edit'}, "");
	}

print "<form action=save_bifc.cgi>\n";
print "<input type=hidden name=new value=\"$in{'new'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
if($in{'vlan'} == 1) {
	print "<input type=hidden name=vlan value=\"$in{'vlan'}\">\n";
} elsif($in{'bond'} == 1) {
	print "<input type=hidden name=bond value=\"$in{'bond'}\">\n";
}

print "<table border width=100%>\n";
print "<tr $tb> <td><b>",
      $in{'virtual'} || $b && $b->{'virtual'} ne "" ? $text{'bifc_desc2'}
						    : $text{'bifc_desc1'},
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'ifcs_name'}</b></td> <td>\n";
if ($in{'new'} && $in{'virtual'}) {
	print "<input type=hidden name=name value=$in{'virtual'}>\n";
	print "$in{'virtual'}:<input name=virtual size=3>\n";
	}
elsif ($in{'new'}) {
	if($in{'vlan'} == 1) {
		print "auto";
		print "<input type='hidden' name='name' value='auto' />"
	} else {
		print "<input name=name size=6>\n";
 	}

	}
else {
	print "<font size=+1><tt>$b->{'fullname'}</tt></font>\n";
	}
print "</td>\n";

print "<td><b>$text{'ifcs_ip'}</b></td> <td>\n";
$virtual = (!$b && $in{'virtual'}) || ($b && $b->{'virtual'} ne "");
$dhcp = &can_edit("dhcp") && !$virtual;
$bootp = &can_edit("bootp") && !$virtual;
if ($dhcp) {
	printf "<input type=radio name=mode value=dhcp %s> %s\n",
		$b && $b->{'dhcp'} ? "checked" : "", $text{'ifcs_dhcp'};
	}
if ($bootp) {
	printf "<input type=radio name=mode value=bootp %s> %s\n",
		$b && $b->{'bootp'} ? "checked" : "", $text{'ifcs_bootp'};
	}
if ($dhcp || $bootp) {
	printf "<input type=radio name=mode value=address %s> %s\n",
		!$b || (!$b->{'bootp'} && !$b->{'dhcp'}) ? "checked" : "",
		$text{'ifcs_static'};
	}
else {
	print "<input type=hidden name=mode value=address>\n";
	}
printf "<input name=address size=15 value=\"%s\"></td> </tr>\n",
	$b && !$b->{'bootp'} && !$b->{'dhcp'} ? $b->{'address'} : "";

print "<tr> <td><b>$text{'ifcs_mask'}</b></td>\n";
if ($in{'virtual'} && $in{'new'} && $virtual_netmask) {
	# Virtual netmask cannot be edited
	print "<td>$virtual_netmask</td>\n";
	}
elsif (&can_edit("netmask", $b) && $access{'netmask'}) {
	printf "<td><input name=netmask size=15 value='%s'></td>\n",
		$b ? $b->{'netmask'} : $config{'def_netmask'};
	}
else {
	printf "<td>%s</td>\n", $b ? $b->{'netmask'} : $text{'ifcs_auto'};
	}

print "<td><b>$text{'ifcs_broad'}</b></td>\n";
if (&can_edit("broadcast", $b) && $access{'broadcast'}) {
	printf "<td><input name=broadcast size=15 value='%s'></td>\n",
		$b ? $b->{'broadcast'} : $config{'def_broadcast'};
	}
else {
	printf "<td>%s</td> </tr>\n", $b ? $b->{'broadcast'}
					 : $text{'ifcs_auto'};
	}

print "<tr> <td><b>$text{'ifcs_mtu'}</b></td>\n";
if (&can_edit("mtu", $b) && $access{'mtu'}) {
	printf "<td><input name=mtu size=15 value='%s'></td>\n",
		$b ? $b->{'mtu'} : $config{'def_mtu'};
	}
else {
	printf "<td>%s</td>\n", $b && $b->{'mtu'} ? $b->{'mtu'}
						  : $text{'ifcs_auto'};
	}

print "<td><b>$text{'ifcs_act'}</b></td>\n";
if (&can_edit("up", $b) && $access{'up'}) {
	printf "<td><input type=radio name=up value=1 %s> $text{'yes'}\n",
		!$b || $b->{'up'} ? "checked" : "";
	printf "<input type=radio name=up value=0 %s> $text{'no'}</td>\n",
		$b && !$b->{'up'} ? "checked" : "";
	}
else {
	printf "<td>%s</td> </tr>\n",
		!$b ? $text{'yes'} :
		$b->{'up'} ? $text{'yes'} : $text{'no'};
	}

print "<tr> <td colspan=2></td>\n";
if ($b && $b->{'virtual'} eq "") {
	print "<td><b>$text{'ifcs_virts'}</b></td>\n";
	$vcount = 0;
	foreach $vb (@boot) {
		if ($vb->{'virtual'} ne "" && $vb->{'name'} eq $b->{'name'}) {
			$vcount++;
			}
		}
	print "<td>$vcount\n";
	if ($access{'virt'} && !$noos_support_add_virtifcs) {
		print "(<a href='edit_bifc.cgi?new=1&virtual=$b->{'name'}'>",
		      "$text{'ifcs_addvirt'}</a>)\n";
		}
	print "</td>\n";
	}
print "</tr>\n";

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
     
print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($access{'bootonly'}) {
	# Can only save both boot-time and active
	if ($in{'new'}) {
		print "<td><input type=submit ",
		      "name=activate value=\"$text{'bifc_capply'}\"></td>\n";
		}
	else {
		print "<td><input type=submit ",
		      "name=activate value=\"$text{'bifc_apply'}\"></td>\n";
		if ($access{'delete'}) {
			print "<td align=right><input type=submit ",
			      "name=unapply value=\"$text{'bifc_dapply'}\"></td>\n";
			}
		}
	}
else {
	# Show buttons to save both boot-time and/or active
	if ($in{'new'}) {
		print "<td><input type=submit value=\"$text{'create'}\"></td>\n";
		print "<td align=right><input type=submit ",
		      "name=activate value=\"$text{'bifc_capply'}\"></td>\n";
		}
	else {
		print "<td><input type=submit value=\"$text{'save'}\"></td>\n"
			unless $always_apply_ifcs;
		if (!($b->{'bootp'} || $b->{'dhcp'}) || defined(&apply_interface)) {
			print "<td align=center><input type=submit ",
			      "name=activate value=\"$text{'bifc_apply'}\"></td>\n";
			}
		if ($access{'delete'}) {
			print "<td align=center><input type=submit ",
			      "name=unapply value=\"$text{'bifc_dapply'}\"></td>\n";
			print "<td align=right><input type=submit name=delete ",
			      "value=\"$text{'delete'}\"></td>\n"
				unless $noos_support_delete_ifcs;
			}
		}
	}
print "</tr></table></form>\n";

&ui_print_footer("list_ifcs.cgi", $text{'ifcs_return'});

