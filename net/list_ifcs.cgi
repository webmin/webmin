#!/usr/local/bin/perl
# list_ifcs.cgi
# List active and boot-time interfaces

require './net-lib.pl';
&ReadParse();
$access{'ifcs'} || &error($text{'ifcs_ecannot'});
$allow_add = &can_create_iface() && !$noos_support_add_ifcs;
&ui_print_header(undef, $text{'ifcs_title'}, "");

# Get interfaces
@act = &active_interfaces(1);
@boot = &boot_interfaces();
@boot = sort iface_sort @boot;

# Start tabs for active/boot time interfaces
@tabs = ( [ "active", $text{'ifcs_now'}, "list_ifcs.cgi?mode=active" ] );
$defmode = "active";
if (!$access{'bootonly'}) {
	push(@tabs, [ "boot", $text{'ifcs_boot'}, "list_ifcs.cgi?mode=boot" ] );
	$defmode = "boot";
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $defmode, 1);

# Show interfaces that are currently active
if (!$access{'bootonly'}) {
	# Table heading and links
	print &ui_tabs_start_tab("mode", "active");
	print $text{'ifcs_activedesc'},"<p>\n";
	local @tds;
	@links = ( );
	if ($access{'ifcs'} >= 2) {
		print &ui_form_start("delete_aifcs.cgi", "post");
		push(@links, &select_all_link("d"),
			     &select_invert_link("d") );
		}
	push(@tds, "width=5 valign=top");
	push(@tds, "width=20% valign=top", "width=20% valign=top",
		   "width=20% valign=top", "width=20% valign=top");
	push(@tds, "width=20% valign=top") if (&supports_address6());
	push(@tds, "width=5% valign=top");
	if ($allow_add) {
		push(@links,
		     &ui_link("edit_aifc.cgi?new=1",$text{'ifcs_add'}));
		}
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'ifcs_name'},
				  $text{'ifcs_type'},
				  $text{'ifcs_ip'},
				  $text{'ifcs_mask'},
				  &supports_address6() ?
					( $text{'ifcs_ip6'} ) : ( ),
				  $text{'ifcs_status'} ], 100, 0, \@tds);

	# Show table of interfaces
	@act = sort iface_sort @act;
	foreach $a (@act) {
		next if ($access{'hide'} &&	# skip hidden
			 (!$a->{'edit'} || !&can_iface($a)));
		local $mod = &module_for_interface($a);
		local %minfo = $mod ? &get_module_info($mod->{'module'}) : ( );
		local @cols;
		if ($a->{'edit'} && &can_iface($a) && $a->{'address'}) {
			push(@cols,
			    "<a href=\"edit_aifc.cgi?idx=$a->{'index'}\">".
			    &html_escape($a->{'fullname'})."</a>");
			}
		elsif (!$a->{'edit'} && $mod) {
			push(@cols,
			   "<a href=\"mod_aifc.cgi?idx=$a->{'index'}\">".
			   &html_escape($a->{'fullname'})."</a>");
			}
		else {
			push(@cols, &html_escape($a->{'fullname'}));
			}
		if ($a->{'virtual'} ne "") {
			$cols[0] = "&nbsp;&nbsp;".$cols[0];
			}
		if (%minfo && $minfo{'dir'} eq 'virtual-server') {
			# Shorten name
			$minfo{'desc'} = $text{'index_vmin'};
			}
		push(@cols, &iface_type($a->{'name'}).
		      ($a->{'virtual'} eq "" ||
		       $mod ? "" : " ($text{'ifcs_virtual'})").
		      (%minfo ? " ($minfo{'desc'})" : "").
		      ($a->{'speed'} ? " ".$a->{'speed'} : ""));
		push(@cols, &html_escape($a->{'address'}) ||
			    $text{'ifcs_noaddress'});
		push(@cols, &html_escape($a->{'netmask'}) ||
			    $text{'ifcs_nonetmask'});
		if (&supports_address6()) {
			push(@cols, join("<br>\n", map { &html_escape($_) }
						    @{$a->{'address6'}}));
			}
		push(@cols, $a->{'up'} ? $text{'ifcs_up'} :
			"<font color=#ff0000>$text{'ifcs_down'}</font>");
		if ($a->{'edit'} && &can_iface($a)) {
			print &ui_checked_columns_row(\@cols, \@tds, "d",
						      $a->{'fullname'});
			}
		else {
			print &ui_columns_row([ "", @cols ], \@tds);
			}
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	if ($access{'ifcs'} >= 2) {
		print &ui_form_end([ [ "delete", $text{'index_delete1'} ] ]);
		}
	print &ui_tabs_end_tab();
	}

# Show interfaces that get activated at boot
print &ui_tabs_start_tab("mode", "boot");
print $text{'ifcs_bootdesc'},"<p>\n";
print &ui_form_start("delete_bifcs.cgi", "post");
@links = ( &select_all_link("b", 1),
	   &select_invert_link("b", 1) );
if ($allow_add) {
	push(@links, &ui_link("edit_bifc.cgi?new=1",$text{'ifcs_add'}));
	if (defined(&supports_bonding) && &supports_bonding()) {
		push(@links, &ui_link("edit_bifc.cgi?new=1&bond=1",$text{'bonding_add'}));
	}
	if (defined(&supports_vlans) && &supports_vlans()) {
		push(@links, &ui_link("edit_bifc.cgi?new=1&vlan=1",$text{'vlan_add'}));
	}
	}
if ($allow_add && defined(&supports_bridges) && &supports_bridges()) {
	push(@links, &ui_link("edit_bifc.cgi?new=1&bridge=1",$text{'ifcs_badd'}));
	}
if ($allow_add && defined(&supports_ranges) && &supports_ranges()) {
	push(@links, &ui_link("edit_range.cgi?new=1",$text{'ifcs_radd'}));
	}
print &ui_links_row(\@links);
@tds = ( "width=5 valign=top", "width=20% valign=top", "width=20% valign=top",
	 "width=20% valign=top", "width=20% valign=top" );
push(@tds, "width=20% valign=top xxx") if (&supports_address6());
push(@tds, "width=5% valign=top");
print &ui_columns_start([ "",
			  $text{'ifcs_name'},
			  $text{'ifcs_type'},
			  $text{'ifcs_ip'},
			  $text{'ifcs_mask'},
			  &supports_address6() ? ( $text{'ifcs_ip6'} ) : ( ),
			  $text{'ifcs_act'} ], 100, 0, \@tds);

foreach $a (@boot) {
	local $can = $a->{'edit'} && &can_iface($a);
	next if ($access{'hide'} && !$can);	# skip hidden
	local @cols;
	local @mytds = @tds;
	if ($a->{'range'} ne "") {
		# A range of addresses
		local $rng = &text('ifcs_range', $a->{'range'});
		if ($can && ($gconfig{'os_type'} eq 'debian-linux') && &has_command("")) {
			$link = "edit_bifc.cgi?idx=$a->{'index'}";
			if(&iface_type($a->{'name'}) eq 'Bonded'){
				$link = $link . "&bond=1";
			} elsif (&iface_type($a->{'name'}) =~ /^(.*) (VLAN)$/) {
				$link = $link . "&vlan=1";
			}
			push(@cols, "<a href='$link'" . &html_escape($a->{'fullname'})."</a>");
			}
		elsif($can) {
			$link = "edit_bifc.cgi?idx=$a->{'index'}";
			push(@cols, "<a href='$link'" . &html_escape($a->{'fullname'})."</a>");
		}
		else {
			push(@cols, &html_escape($rng));
			}
		push(@cols, &iface_type($a->{'name'}));
		push(@cols, "$a->{'start'} - $a->{'end'}");
		if (&supports_address6()) {
			# IPv6 not possible for ranges
			push(@cols, "");
			}
		splice(@mytds, 3, 2, "colspan=2 width=40% valign=top");
		}
	else {
		# A normal single interface
		local $mod = &module_for_interface($a);
		local %minfo = $mod ? &get_module_info($mod->{'module'}) : ( );
		if ($can) {
			$link = "edit_bifc.cgi?idx=$a->{'index'}";
			if(&iface_type($a->{'name'}) eq 'Bonded'){
				$link = $link . "&bond=1";
			} elsif (&iface_type($a->{'name'}) =~ /^(.*) (VLAN)$/) {
				$link = $link . "&vlan=1";
			}
			push(@cols, "<a href='$link'>"
				    .&html_escape($a->{'fullname'})."</a>");
			}
		else {
			push(@cols, &html_escape($a->{'fullname'}));
			}
		if ($a->{'virtual'} ne "") {
			$cols[0] = "&nbsp;&nbsp;".$cols[0];
			}
		if (%minfo && $minfo{'dir'} eq 'virtual-server') {
			# Shorten name
			$minfo{'desc'} = $text{'index_vmin'};
			}
		push(@cols, &iface_type($a->{'name'}).
		     ($a->{'virtual'} eq "" ||
		      $mod ? "" : " ($text{'ifcs_virtual'})").
		     (%minfo ? " ($minfo{'desc'})" : ""));
		push(@cols, $a->{'bootp'} ? $text{'ifcs_bootp'} :
			    $a->{'dhcp'} ? $text{'ifcs_dhcp'} :
			    $a->{'address'} ? &html_escape($a->{'address'}) :
					       $text{'ifcs_noaddress'});
		push(@cols, $a->{'bootp'} ? $text{'ifcs_bootp'} :
                            $a->{'dhcp'} ? $text{'ifcs_dhcp'} :
			    $a->{'netmask'} ? &html_escape($a->{'netmask'}) :
			    		      $text{'ifcs_nonetmask'});
		if (&supports_address6()) {
			push(@cols, $a->{'auto6'} ? $text{'ifcs_auto6'} :
				      join("<br>\n", map { &html_escape($_) }
						    @{$a->{'address6'}}));
			}
		}
	push(@cols, $a->{'up'} ? $text{'yes'} : $text{'no'});
	if ($can) {
		print &ui_checked_columns_row(\@cols, \@mytds, "b",
					      $a->{'fullname'});
		}
	else {
		print &ui_columns_row([ "", @cols ], \@tds);
		}
	}
print &ui_columns_end();
print &ui_links_row(\@links);
if($access{"delete"}) {
print &ui_form_end([ [ "delete", $text{'index_delete2'} ],
                     [ "deleteapply", $text{'index_delete3'} ],
                     undef,
                     [ "apply", $text{'index_apply2'} ] ]);
} else {
print &ui_form_end([ [ "apply", $text{'index_apply2'} ] ]);
}
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

