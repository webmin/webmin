#!/usr/local/bin/perl
# edit_range.cgi
# Edit or create an IP range bootup interface

require './net-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&can_create_iface() && $access{'virt'} || &error($text{'ifcs_ecannot'});
	&ui_print_header(undef, $text{'range_create'}, "");
	}
else {
	@boot = &boot_interfaces();
	$b = $boot[$in{'idx'}] if ($in{'idx'} =~ /^\d+\z/);
	$b && $b->{'range'} ne '' || &error($text{'daifcs_egone'});
	&can_iface($b) || &error($text{'ifcs_ecannot_this'});
	
	&ui_print_header(undef, $text{'range_edit'}, "");
	}

# Form start
print &ui_form_start("save_range.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'range_header'}, undef, 2);

# OS-specific range input
&range_input($b);

# End and buttons
print &ui_table_end();
if ($in{'new'}) {
	# Users limited to boot-time and active changes together can only
	# create and activate
	print &ui_form_end([
		!$access{'bootonly'} ? ( [ undef, $text{'create'} ] ) : ( ),
		[ 'activate', $text{'bifc_capply'} ] ]);
	}
else {
	# Deleting needs the delete permission, and boot-only users must also
	# deactivate the range
	print &ui_form_end([
		!$always_apply_ifcs && !$access{'bootonly'} ?
			( [ undef, $text{'save'} ] ) : ( ),
		defined(&apply_interface) ?
			( [ 'activate', $text{'bifc_apply'} ] ) : ( ),
		defined(&unapply_range) && $access{'delete'} ?
			( [ 'unapply', $text{'bifc_dapply'} ] ) : ( ),
		!$noos_support_delete_ifcs && $access{'delete'} &&
		!$access{'bootonly'} ?
			( [ 'delete', $text{'delete'} ] ) : ( ),
		]);
	}

&ui_print_footer("list_ifcs.cgi?mode=boot", $text{'ifcs_return'});

