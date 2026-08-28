#!/usr/local/bin/perl
# Display detailed information for one enumerated hardware device.

use strict;
use warnings;

require './hardware-info-lib.pl'; ## no critic

our (%in, %text);

ReadParse();
error_setup($text{'view_error'});

my %valid_types = map { $_, 1 } hardware_device_types();
my $requested = defined($in{'type'}) ? $in{'type'} : "";
my $type = $valid_types{$requested} ? $requested : "";
error($text{'view_etype'}) if (!$type);
my $id = defined($in{'id'}) ? $in{'id'} : "";
my $device = get_hardware_device($type, $id);
error($text{'view_enodevice'}) if (!$device);

ui_print_header($text{"type_$type"},
	text('view_title', html_escape($device->{'name'})), "", undef, 0, 1);

print ui_table_start($text{'view_details'}, "width=100%", 2,
	[ "width=30%", undef ]);
foreach my $detail (@{$device->{'details'}}) {
	my ($key, $value, $format) = @$detail;
	next if (!defined($value) || $value eq "");
	print ui_table_row($text{"detail_$key"} || html_escape($key),
		format_hardware_value($value, $format));
	}
print ui_table_end();

# Keep driver bindings and low-level uevent properties in one expanded panel.
my $has_driver = $device->{'driver'} || @{$device->{'modules'}} ||
		 $device->{'modalias'};
my $has_properties = keys(%{$device->{'properties'}});
my $has_interfaces = $type eq 'usb' && @{$device->{'interfaces'}};
if ($has_driver || $has_properties || $has_interfaces) {
	print ui_hidden_table_start($text{'view_driver'}, "width=100%", 2,
		"driver_properties", 1, [ "width=30%", undef ]);
	print ui_table_row($text{'detail_driver'},
		html_escape($device->{'driver'})) if ($device->{'driver'});
	print ui_table_row($text{'detail_module'},
		module_links($device->{'modules'}, $device->{'driver'}))
		if (@{$device->{'modules'}} || $device->{'driver'});
	print ui_table_row($text{'detail_modalias'},
		ui_tag('tt', html_escape($device->{'modalias'})))
		if ($device->{'modalias'});

	# USB interface class and driver bindings belong with other kernel details.
	foreach my $interface (@{$device->{'interfaces'} || [ ]}) {
		my $label = $interface->{'name'} ?
			text('view_interface_name', html_escape($interface->{'id'}),
				html_escape($interface->{'name'})) :
			html_escape($interface->{'id'});
		my @details = (text('view_interface_class',
			html_escape($interface->{'class'})));
		push(@details, text('view_interface_driver',
			html_escape($interface->{'driver'})))
			if ($interface->{'driver'});
		push(@details, text('view_interface_module',
			module_links($interface->{'module'} ?
				[ $interface->{'module'} ] : [ ],
				$interface->{'driver'})))
			if ($interface->{'module'} || $interface->{'driver'});
		print ui_table_row($label, join("<br>", @details));
		}

	# Raw properties already shown with friendly labels are omitted here.
	foreach my $key (sort keys(%{$device->{'properties'}})) {
		next if ($key eq 'DRIVER' && $device->{'driver'});
		next if ($key eq 'MODALIAS' && $device->{'modalias'});
		print ui_table_row(ui_tag('tt', html_escape($key)),
			ui_tag('tt', html_escape($device->{'properties'}->{$key})));
		}
	print ui_hidden_table_end();
	}

ui_print_footer("index.cgi?type=".urlize($type), $text{'view_return'});

# format_hardware_value(value, format)
# Applies units and localized enums while escaping every raw sysfs value.
sub format_hardware_value
{
my ($value, $format) = @_;
return nice_size($value) if ($format && $format eq 'size' &&
				     $value =~ /^\d+(?:\.\d+)?$/);
return $value ? $text{'yes'} : $text{'no'}
	if ($format && $format eq 'yesno');
return html_escape($text{"storage_$value"})
	if ($format && $format eq 'storage_type');
return html_escape($text{"network_$value"})
	if ($format && $format eq 'network_type');
return html_escape(text('format_mbps', $value))
	if ($format && ($format eq 'network_speed' || $format eq 'usb_speed'));
return html_escape(text('format_mhz', hardware_number($value)))
	if ($format && $format eq 'cpu_frequency');
return html_escape($value);
}

# module_links(modules, [driver])
# Links loaded module names to their module metadata pages.
sub module_links
{
my ($modules, $driver) = @_;
return $text{'module_builtin'} if (!@$modules && $driver);
return join(", ", map {
	ui_link("module.cgi?name=".urlize($_), ui_tag('tt', html_escape($_)))
	} @$modules);
}
