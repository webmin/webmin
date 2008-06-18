#!/usr/local/bin/perl
# edit_aifc.cgi
# Edit or create an active interface

require './net-lib.pl';

&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'aifc_create'}, "");
	&can_create_iface() || &error($text{'ifcs_ecannot'});
	}
else {
	@act = &active_interfaces();
	$a = $act[$in{'idx'}];
	&can_iface($a) || &error($text{'ifcs_ecannot_this'});
	&ui_print_header(undef, $text{'aifc_edit'}, "");
	}

print "<form action=save_aifc.cgi>\n";
print "<input type=hidden name=new value=\"$in{'new'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",
      $in{'virtual'} || $a && $a->{'virtual'} ne "" ? $text{'aifc_desc2'}
						    : $text{'aifc_desc1'},
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'ifcs_name'}</b></td> <td>\n";
if ($in{'new'} && $in{'virtual'}) {
	print "<input type=hidden name=name value=$in{'virtual'}>\n";
	print "$in{'virtual'}:<input name=virtual size=3>\n";
	}
elsif ($in{'new'}) {
	print "<input name=name size=6>\n";
	}
else {
	print "<font size=+1><tt>$a->{'fullname'}</tt></font>\n";
	}
print "</td>\n";

print "<td><b>$text{'ifcs_ip'}</b></td>\n";
printf "<td><input name=address size=15 value=\"%s\"></td> </tr>\n",
	$a ? $a->{'address'} : "";

# Show netmask
print "<tr> <td><b>$text{'ifcs_mask'}</b></td> <td>\n";
if ($in{'virtual'} && $in{'new'} && $virtual_netmask) {
	# Virtual netmask cannot be edited
	print "$virtual_netmask\n";
	}
elsif (!$access{'netmask'}) {
	print $a ? $a->{'netmask'} : $config{'def_netmask'};
	}
else {
	print &ui_opt_textbox("netmask", $a ? $a->{'netmask'}
					    : $config{'def_netmask'}, 15,
			      $text{'ifcs_auto'});
	}
print "</td>\n";

# Show broadcast address
if( $in{'new'} || (!&is_ipv6_address($a->{'address'})) ){
print "<td><b>$text{'ifcs_broad'}</b></td> <td>\n";
if (!$access{'broadcast'}) {
	print $a ? $a->{'broadcast'} :
	      $config{'def_broadcast'} ? $config{'def_broadcast'} :
					 $text{'ifcs_auto'};
	}
else {
	print &ui_opt_textbox("broadcast", $a ? $a->{'broadcast'}
					      : $config{'def_broadcast'}, 15,
			      $text{'ifcs_auto'});
	}
print "</td> </tr>\n";
}

# Show MTU
print "<tr> <td><b>$text{'ifcs_mtu'}</b></td> <td>\n";
if (!$access{'mtu'}) {
	print $a ? $a->{'mtu'} :
	      $config{'def_mtu'} ? $config{'def_mtu'} : $text{'default'};
	}
else {
	print &ui_opt_textbox("mtu", $a ? $a->{'mtu'}
					: $config{'def_mtu'}, 15,
			      $text{'ifcs_auto'});
	}
print "</td>\n";

print "<td><b>$text{'ifcs_status'}</b></td> <td>\n";
if (!$access{'up'}) {
	print !$a ? $text{'ifcs_up'} :
		$a->{'up'} ? $text{'ifcs_up'} : $text{'ifcs_down'};
	}
else {
	print &ui_radio("up", !$a || $a->{'up'} ? 1 : 0,
			[ [ 1, $text{'ifcs_up'} ], [ 0, $text{'ifcs_down'} ] ]);
	}
print "</td> </tr>\n";

if ((!$a && $in{'virtual'} eq "") ||
    ($a && $a->{'virtual'} eq "" && &iface_hardware($a->{'name'}))) {
	print "<tr> <td><b>$text{'aifc_hard'}</b></td> <td>\n";
	if ($in{'new'}) {
		printf "<input type=radio name=ether_def value=1 %s> %s\n",
			$a ? "" : "checked", $text{'aifc_default'};
		printf "<input type=radio name=ether_def value=0 %s>\n",
			$a ? "checked" : "";
		}
	printf "<input name=ether size=18 value=\"%s\"></td>\n",
		$a ? $a->{'ether'} : "";
	}
else {
	print "<tr> <td colspan=2></td>\n";
	}
if ($a && $a->{'virtual'} eq "") {
	print "<td><b>$text{'ifcs_virts'}</b></td>\n";
	$vcount = 0;
	foreach $va (@act) {
		if ($va->{'virtual'} ne "" && $va->{'name'} eq $a->{'name'}) {
			$vcount++;
			}
		}
	print "<td>$vcount\n";
	print "(<a href='edit_aifc.cgi?new=1&virtual=$a->{'name'}'>",
	      "$text{'ifcs_addvirt'}</a>)</td>\n";
	}
print "</tr>\n";
     

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value=\"$text{'create'}\"></td>\n";
	}
else {
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
	if ($access{'delete'}) {
		print "<td align=right><input type=submit name=delete ",
		      "value=\"$text{'delete'}\"></td>\n";
		}
	}
print "</tr></table></form>\n";

&ui_print_footer("list_ifcs.cgi?mode=active", $text{'ifcs_return'});

