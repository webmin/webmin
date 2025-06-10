#!/usr/local/bin/perl
# edit_range.cgi
# Edit or create an IP range bootup interface

require './net-lib.pl';
$access{'ifcs'} == 2 || $access{'ifcs'} == 3 || &error($text{'ifcs_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'range_create'}, "");
	}
else {
	@boot = &boot_interfaces();
	$b = $boot[$in{'idx'}];

	if ($access{'ifcs'} == 3) {
		map { $can_interfaces{$_}++ } split(/\s+/, $access{'interfaces'});
		if (! $can_interfaces{$b->{'fullname'}}) {
			&error($text{'ifcs_ecannot_this'});
			}
		}
	
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
	print &ui_form_end([ [ undef, $text{'create'} ],
			     [ 'activate', $text{'bifc_capply'} ] ]);
	}
else {
	print &ui_form_end([
		!$always_apply_ifcs ? ( [ undef, $text{'save'} ] ) : ( ),
		defined(&apply_interface) ?
			( [ 'activate', $text{'bifc_apply'} ] ) : ( ),
		defined(&unapply_interface) ?
			( [ 'unapply', $text{'bifc_dapply'} ] ) : ( ),
		!$noos_support_delete_ifcs ?
			( [ 'delete', $text{'delete'} ] ) : ( ),
		]);
	}

&ui_print_footer("list_ifcs.cgi?mode=boot", $text{'ifcs_return'});

