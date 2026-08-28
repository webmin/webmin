#!/usr/local/bin/perl
# Display a read-only system hardware report and device inventory.

use strict;
use warnings;

require './hardware-info-lib.pl'; ## no critic

our (%in, %text);

ReadParse();

# Collect each group once so tab counts and rows describe the same snapshot.
my @all_types = hardware_device_types();
my %devices;
foreach my $type (@all_types) {
	my @list = list_hardware_devices($type);
	$devices{$type} = \@list;
	}
# Sensors are optional on virtual machines and systems without hwmon drivers.
my @types = grep { $_ ne 'sensor' || @{$devices{$_}} } @all_types;
my $summary = hardware_system_summary($devices{'cpu'});

ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

# The report card and device groups are peers so the page opens with one
# focused view instead of stacking the summary above every inventory.
my @tabs = ([ 'system', $text{'type_system'} ], map {
	[ $_, $text{"type_$_"}.'&nbsp;'.
		ui_tag('sup', scalar(@{$devices{$_}})) ]
	} @types);
my %valid_tabs = map { $_->[0], 1 } @tabs;
my $requested = defined($in{'type'}) ? $in{'type'} : "";
my $active = $valid_tabs{$requested} ? $requested : 'system';

print ui_tabs_start(\@tabs, "type", $active, 1);
foreach my $tab ('system', @types) {
	print ui_tabs_start_tab("type", $tab);
	print ui_div($text{"index_${tab}_desc"});
	if ($tab eq 'system') {
		print_system_summary($summary);
		}
	else {
		print_device_table($tab, $devices{$tab});
		}
	print ui_tabs_end_tab("type", $tab);
	}
print ui_tabs_end(1);

ui_print_footer("/", $text{'index'});

# print_system_summary(summary)
# Renders the system, board, firmware and resource report card.
sub print_system_summary
{
my ($summary) = @_;
print ui_table_start(undef, "width=100%", 4,
	[ "width=20%", "width=30%", "width=20%", "width=30%" ]);

my $system = join(" ", grep { defined($_) && $_ ne "" }
	($summary->{'system_vendor'}, $summary->{'system_product'},
	 $summary->{'system_version'}));
my $board = join(" ", grep { defined($_) && $_ ne "" }
	($summary->{'board_vendor'}, $summary->{'board_name'},
	 $summary->{'board_version'}));
my $bios = join(" ", grep { defined($_) && $_ ne "" }
	($summary->{'bios_vendor'}, $summary->{'bios_version'},
	 $summary->{'bios_date'}));
my $chassis_type = hardware_chassis_type_name($summary->{'chassis_type'});
my $chassis = $chassis_type || $summary->{'chassis_version'} ?
	join(" ", grep { defined($_) && $_ ne "" }
		($summary->{'chassis_vendor'}, $chassis_type,
		 $summary->{'chassis_version'})) : "";
my $models = @{$summary->{'cpu_models'}} ?
	join(", ", @{$summary->{'cpu_models'}}) : $text{'unknown'};
my $processor_count = text(
	$summary->{'cpu_count'} == 1 ? 'index_processor_count_one' :
		'index_processor_count_many', $summary->{'cpu_count'});
my $package_count = $summary->{'cpu_sockets'} == 1 ?
	$text{'index_package_count_one'} : $summary->{'cpu_sockets'} > 1 ?
	text('index_package_count_many', $summary->{'cpu_sockets'}) :
	$text{'index_package_count_unknown'};
my $processors = text('index_processors', $processor_count,
	$package_count, $models);
my $firmware_mode = $text{'firmware_'.$summary->{'firmware_mode'}};
my $secure_boot = defined($summary->{'secure_boot'}) ?
	($summary->{'secure_boot'} ? $text{'secure_boot_enabled'} :
	 $text{'secure_boot_disabled'}) : $text{'unknown'};
my $tpm = @{$summary->{'tpms'}} ?
	text('index_tpm_detected', join(", ", @{$summary->{'tpms'}})) :
	$text{'index_tpm_missing'};

# Missing optional DMI values are omitted instead of leaving empty labels.
my @rows = (
	[ $text{'index_hostname'}, $summary->{'hostname'} ],
	[ $text{'index_os'}, $summary->{'os'} ],
	[ $text{'index_kernel'}, $summary->{'kernel'} ],
	[ $text{'index_architecture'}, $summary->{'architecture'} ],
	[ $text{'index_system'}, $system ],
	[ $text{'index_system_serial'}, $summary->{'system_serial'} ],
	[ $text{'index_board'}, $board ],
	[ $text{'index_board_serial'}, $summary->{'board_serial'} ],
	[ $text{'index_bios'}, $bios ],
	[ $text{'index_firmware_mode'}, $firmware_mode ],
	[ $text{'index_secure_boot'},
	  $summary->{'firmware_mode'} eq 'uefi' ? $secure_boot : undef ],
	[ $text{'index_tpm'}, $tpm ],
	[ $text{'index_memory'}, defined($summary->{'memory'}) ?
	  nice_size($summary->{'memory'}) : undef, 1 ],
	[ $text{'index_processors_label'}, $processors ],
	[ $text{'index_uuid'}, $summary->{'system_uuid'} ],
	[ $text{'index_chassis'}, $chassis ],
	[ $text{'index_chassis_serial'}, $summary->{'chassis_serial'} ],
	);
foreach my $row (@rows) {
	my ($label, $value, $formatted) = @$row;
	next if (!defined($value) || $value eq "");
	print ui_table_row($label, $formatted ? $value : hardware_html($value));
	}
print ui_table_end();
}

# print_device_table(type, devices)
# Dispatches to the compact table appropriate for an inventory group.
sub print_device_table
{
my ($type, $list) = @_;
if (!@$list) {
	print ui_alert($text{"index_empty_$type"}, 'info');
	return;
	}
if ($type eq 'pci') {
	print_pci_table($list);
	}
elsif ($type eq 'usb') {
	print_usb_table($list);
	}
elsif ($type eq 'storage') {
	print_storage_table($list);
	}
elsif ($type eq 'network') {
	print_network_table($list);
	}
elsif ($type eq 'cpu') {
	print_cpu_table($list);
	}
else {
	print_sensor_table($list);
	}
}

# print_pci_table(devices)
# Shows PCI address, class and kernel binding at a glance.
sub print_pci_table
{
my ($list) = @_;
print ui_columns_start([
	$text{'index_device'}, $text{'index_class'}, $text{'index_location'},
	$text{'index_driver'}, $text{'index_module'},
	]);
foreach my $device (@$list) {
	print ui_columns_row([
		hardware_device_link('pci', $device),
		hardware_html($device->{'class'}),
		ui_tag('tt', hardware_html($device->{'id'})),
		hardware_html($device->{'driver'}),
		hardware_module_links($device->{'modules'}, $device->{'driver'}),
		]);
	}
print ui_columns_end();
}

# print_usb_table(devices)
# Shows physical USB devices and aggregated interface driver bindings.
sub print_usb_table
{
my ($list) = @_;
print ui_columns_start([
	$text{'index_device'}, $text{'index_location'}, $text{'index_speed'},
	$text{'index_driver'}, $text{'index_module'},
	]);
foreach my $device (@$list) {
	my $location = defined($device->{'bus_number'}) &&
		       defined($device->{'device_number'}) ?
		text('index_usb_location', $device->{'bus_number'},
			$device->{'device_number'}) : $device->{'id'};
	my $speed = $device->{'speed'} ?
		text('format_mbps', $device->{'speed'}) : "";
	print ui_columns_row([
		hardware_device_link('usb', $device),
		hardware_html($location), hardware_html($speed),
		hardware_html($device->{'driver'}),
		hardware_module_links($device->{'modules'}, $device->{'driver'}),
		]);
	}
print ui_columns_end();
}

# print_storage_table(devices)
# Shows whole block devices, capacity, media kind and kernel binding.
sub print_storage_table
{
my ($list) = @_;
print ui_columns_start([
	$text{'index_device'}, $text{'index_model'}, $text{'index_capacity'},
	$text{'index_type'}, $text{'index_driver'}, $text{'index_module'},
	]);
foreach my $device (@$list) {
	print ui_columns_row([
		hardware_device_link('storage', $device, $device->{'device'}),
		hardware_html($device->{'model'}),
		defined($device->{'size'}) ? nice_size($device->{'size'}) : "",
		hardware_html($text{'storage_'.$device->{'kind'}}),
		hardware_html($device->{'driver'}),
		hardware_module_links($device->{'modules'}, $device->{'driver'}),
		]);
	}
print ui_columns_end();
}

# print_sensor_table(devices)
# Shows only detected hwmon readings, keeping the optional tab compact.
sub print_sensor_table
{
my ($list) = @_;
print ui_columns_start([
	$text{'index_sensor'}, $text{'index_chip'}, $text{'index_type'},
	$text{'index_reading'}, $text{'index_driver'}, $text{'index_module'},
	]);
foreach my $device (@$list) {
	print ui_columns_row([
		hardware_device_link('sensor', $device),
		hardware_html($device->{'chip'}),
		hardware_html($text{'sensor_'.$device->{'kind'}}),
		hardware_html($device->{'reading'}),
		hardware_html($device->{'driver'}),
		hardware_module_links($device->{'modules'}, $device->{'driver'}),
		]);
	}
print ui_columns_end();
}

# print_network_table(devices)
# Shows all network interfaces, including virtual interfaces, and link state.
sub print_network_table
{
my ($list) = @_;
print ui_columns_start([
	$text{'index_interface'}, $text{'index_type'}, $text{'index_address'},
	$text{'index_state'}, $text{'index_speed'}, $text{'index_driver'},
	$text{'index_module'},
	]);
foreach my $device (@$list) {
	my $speed = $device->{'speed'} ?
		text('format_mbps', $device->{'speed'}) : "";
	print ui_columns_row([
		hardware_device_link('network', $device),
		hardware_html($text{'network_'.$device->{'kind'}}),
		ui_tag('tt', hardware_html($device->{'address'})),
		hardware_html($device->{'state'}), hardware_html($speed),
		hardware_html($device->{'driver'}),
		hardware_module_links($device->{'modules'}, $device->{'driver'}),
		]);
	}
print ui_columns_end();
}

# print_cpu_table(devices)
# Shows logical processor topology and current operating state.
sub print_cpu_table
{
my ($list) = @_;
print ui_columns_start([
	$text{'index_processor'}, $text{'index_model'}, $text{'index_socket'},
	$text{'index_core'}, $text{'index_state'}, $text{'index_frequency'},
	]);
foreach my $device (@$list) {
	my $frequency = $device->{'frequency'} ?
		text('format_mhz', hardware_number($device->{'frequency'})) : "";
	print ui_columns_row([
		hardware_device_link('cpu', $device),
		hardware_html($device->{'model'}),
		hardware_html($device->{'socket'}), hardware_html($device->{'core'}),
		$device->{'online'} ? $text{'online'} : $text{'offline'},
		hardware_html($frequency),
		]);
	}
print ui_columns_end();
}

# hardware_device_link(type, device)
# Returns an escaped link to the exact inventory item.
sub hardware_device_link
{
my ($type, $device, $label) = @_;
my $url = "view.cgi?type=".urlize($type)."&id=".urlize($device->{'id'});
$label = $device->{'name'} if (!defined($label));
return ui_link($url, hardware_html($label));
}

# hardware_module_links(modules, [driver])
# Returns links to details for loaded modules associated with a device.
sub hardware_module_links
{
my ($modules, $driver) = @_;
return $text{'module_builtin'} if ((!$modules || !@$modules) && $driver);
return "" if (!$modules || !@$modules);
return join(", ", map {
	ui_link("module.cgi?name=".urlize($_), ui_tag('tt', hardware_html($_)))
	} @$modules);
}

# hardware_html(value)
# Escapes a possibly missing hardware value for safe table output.
sub hardware_html
{
my ($value) = @_;
return "" if (!defined($value));
return html_escape($value);
}
