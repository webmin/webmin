#!/usr/local/bin/perl
# Show a form to edit or create an device

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in);
my $conf = &get_iscsi_config();
&ReadParse();

# Get the device, or create a new one
my $device;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'device_create'}, "");
	$device = { 'num' => &find_free_num($conf, 'device'),
		    'type' => 'device',
		    'mode' => 'raid0',
		    'start' => 0 };
	}
else {
	$device = &find($conf, "device", $in{'num'});
	$device || &text('device_egone', $in{'num'});
	&ui_print_header(undef, $text{'device_edit'}, "");
	}

# Show editing form
print &ui_form_start("save_device.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("num", $in{'num'});
print &ui_table_start($text{'device_header'}, undef, 2);

# Device name/number
print &ui_table_row($text{'device_name'},
		    $device->{'type'}.$device->{'num'});

# Combination mode
print &ui_table_row($text{'device_mode'},
		    &ui_radio("mode", $device->{'mode'},
			      [ [ 'raid0', $text{'devices_mode_raid0'} ],
				[ 'raid1', $text{'devices_mode_raid1'} ] ]));

# Component devices / extents
my @poss = map { [ $_->{'type'}.$_->{'num'}, &describe_object($_) ] }
		grep { $_ ne $device }
			( &find($conf, 'extent'), &find($conf, 'device') );
my @got = map { my $name = $_;
		my ($g) = grep { $_->[0] eq $name } @poss;
		$g || [ $name, $name ] } @{$device->{'extents'}};
print &ui_table_row($text{'device_extents'},
	&ui_multi_select("extents", \@got, \@poss, 10, 1, 0,
			 $text{'device_poss'}, $text{'device_got'}, 300));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_devices.cgi", $text{'devices_return'});
