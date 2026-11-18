#!/usr/local/bin/perl
# save_range.cgi
# Create, save or delete a boot-time address range

require './net-lib.pl';
&ReadParse();
@boot = &boot_interfaces();
if ($in{'new'}) {
	&can_create_iface() && !$in{'delete'} && !$in{'unapply'} ||
		&error($text{'ifcs_ecannot'});
	}
else {
	$b = $boot[$in{'idx'}] if ($in{'idx'} =~ /^\d+\z/);
	$b && $b->{'range'} ne '' || &error($text{'daifcs_egone'});
	&can_iface($b) || &error($text{'ifcs_ecannot_this'});
	}

if ($in{'delete'} || $in{'unapply'}) {
	# Delete interface
	&error_setup($text{'bifc_err1'});

	# Users who must change boot-time and active interfaces together have
	# to deactivate a range when deleting it
	$access{'delete'} || &error($text{'ifcs_ecannot_delete'});
	!$access{'bootonly'} || $in{'unapply'} ||
		&error($text{'ifcs_ecannot_active'});
	if ($in{'unapply'}) {
		&error_setup($text{'bifc_err4'});
		&unapply_range($b);
		}
	&delete_interface($b);
	&webmin_log("delete", "range", $b->{'fullname'}, $b);
	}
else {
	# Save or create interface
	&error_setup($text{'range_err'});

	# Users who must change boot-time and active interfaces together have
	# to activate a range when saving it
	!$access{'bootonly'} || $in{'activate'} ||
		&error($text{'ifcs_ecannot_active'});
	if ($in{'new'}) {
		# A range adds virtual interfaces
		$access{'virt'} || &error($text{'ifcs_ecannot_virt'});
		$b = { };
		}
	&parse_range($b, \%in);
	&save_interface($b);

	if ($in{'activate'}) {
		# Make this interface active (if possible)
		&error_setup($text{'bifc_err3'});
		$err = &apply_interface($b);
		$err && &error("<pre>$err</pre>");
		}
	&webmin_log($in{'new'} ? 'create' : 'modify',
		    "range", $b->{'fullname'}, $b);
	}
&redirect("list_ifcs.cgi?mode=boot");

