#!/usr/local/bin/perl
# Functions for collecting read-only Linux hardware information.

use strict;
use warnings;
use POSIX qw(uname);
use Cwd qw(abs_path);

BEGIN { push(@INC, ".."); }
use WebminCore;

init_config();

our (%config, %gconfig, %text);
our $hardware_sys_root;
our $hardware_proc_root;
our $hardware_pci_ids_file;
our $hardware_usb_ids_file;
our $hardware_modinfo_command;
our %hardware_ids_cache;

$hardware_sys_root ||= "/sys";
$hardware_proc_root ||= "/proc";

# hardware_device_types()
# Returns the device groups shown by this module, in display order.
sub hardware_device_types
{
return qw(pci usb storage network cpu sensor);
}

# list_hardware_devices(type)
# Returns all devices in one of the supported inventory groups.
sub list_hardware_devices
{
my ($type) = @_;
return list_pci_devices() if ($type eq 'pci');
return list_usb_devices() if ($type eq 'usb');
return list_storage_devices() if ($type eq 'storage');
return list_network_devices() if ($type eq 'network');
return list_cpu_devices() if ($type eq 'cpu');
return list_sensor_devices() if ($type eq 'sensor');
return ( );
}

# get_hardware_device(type, id)
# Finds a device by its exact enumerated ID. The ID is never used as a path.
sub get_hardware_device
{
my ($type, $id) = @_;
return if (!defined($id));
foreach my $device (list_hardware_devices($type)) {
	return $device if ($device->{'id'} eq $id);
	}
return;
}

# hardware_system_summary([processors])
# Returns the host, kernel, memory, processor and DMI report-card fields.
sub hardware_system_summary
{
my ($processors) = @_;
my ($sysname, $nodename, $release, $version, $machine) = uname();
my $os_type = $gconfig{'real_os_type'} || $gconfig{'os_type'} || $sysname;
my $os_version = $gconfig{'real_os_version'} ||
		 $gconfig{'os_version'} || "";
my $memory = hardware_memtotal();
my @cpus = $processors ? @$processors : list_cpu_devices();
my %models;
my %sockets;
foreach my $cpu (@cpus) {
	$models{$cpu->{'model'}}++ if ($cpu->{'model'});
	$sockets{$cpu->{'socket'}}++ if (defined($cpu->{'socket'}) &&
					   $cpu->{'socket'} ne "");
	}

my %summary = (
	'hostname' => get_system_hostname() || $nodename,
	'os' => join(" ", grep { defined($_) && $_ ne "" }
				($os_type, $os_version)),
	'kernel' => join(" ", grep { defined($_) && $_ ne "" }
				($sysname, $release)),
	'architecture' => $machine,
	'memory' => $memory,
	'cpu_count' => scalar(@cpus),
	'cpu_models' => [ sort keys(%models) ],
	'cpu_sockets' => scalar(keys(%sockets)),
	);

# Fixed sysfs locations expose boot firmware and TPM presence without tools.
$summary{'firmware_mode'} = -d "$hardware_sys_root/firmware/efi" ? 'uefi' :
	$machine =~ /^(?:i.86|x86_64)$/i ? 'bios' : 'other';
$summary{'secure_boot'} = hardware_secure_boot_status()
	if ($summary{'firmware_mode'} eq 'uefi');
my @tpms = grep { /^tpm\d+$/ }
	hardware_directory_entries("$hardware_sys_root/class/tpm");
$summary{'tpms'} = \@tpms;

# DMI exposes the system, board, chassis and firmware identity without tools.
my %dmi_fields = (
	'system_vendor' => 'sys_vendor',
	'system_product' => 'product_name',
	'system_version' => 'product_version',
	'system_serial' => 'product_serial',
	'system_uuid' => 'product_uuid',
	'board_vendor' => 'board_vendor',
	'board_name' => 'board_name',
	'board_version' => 'board_version',
	'board_serial' => 'board_serial',
	'chassis_vendor' => 'chassis_vendor',
	'chassis_type' => 'chassis_type',
	'chassis_version' => 'chassis_version',
	'chassis_serial' => 'chassis_serial',
	'bios_vendor' => 'bios_vendor',
	'bios_version' => 'bios_version',
	'bios_date' => 'bios_date',
	);
foreach my $key (keys(%dmi_fields)) {
	my $value = hardware_read_value(
		"$hardware_sys_root/class/dmi/id/$dmi_fields{$key}");
	$summary{$key} = $value if (defined($value) && $value ne "");
	}
return \%summary;
}

# hardware_memtotal()
# Returns total usable memory in bytes, or undef when procfs is unavailable.
sub hardware_memtotal
{
my $data = hardware_read_file("$hardware_proc_root/meminfo");
return if (!defined($data));
return $1 * 1024 if ($data =~ /^MemTotal:\s+(\d+)\s+kB/im);
return;
}

# hardware_secure_boot_status()
# Returns the UEFI Secure Boot flag, or undef when firmware does not expose it.
sub hardware_secure_boot_status
{
my $efivars = "$hardware_sys_root/firmware/efi/efivars";
foreach my $entry (hardware_directory_entries($efivars, 1)) {
	next if ($entry !~ /^SecureBoot-[0-9a-f-]+$/i);
	my $value = hardware_read_file("$efivars/$entry");
	next if (!defined($value) || length($value) < 5);
	return ord(substr($value, 4, 1)) ? 1 : 0;
	}
return;
}

# list_pci_devices()
# Enumerates PCI functions from sysfs, including their bound driver and module.
sub list_pci_devices
{
my $root = "$hardware_sys_root/bus/pci/devices";
my @devices;
foreach my $id (hardware_directory_entries($root)) {
	my $path = "$root/$id";
	my $vendor = hardware_normalize_id(hardware_read_value("$path/vendor"));
	my $device = hardware_normalize_id(hardware_read_value("$path/device"));
	next if (!$vendor || !$device);
	my $subvendor = hardware_normalize_id(
		hardware_read_value("$path/subsystem_vendor"));
	my $subdevice = hardware_normalize_id(
		hardware_read_value("$path/subsystem_device"));
	my $class_id = hardware_normalize_id(hardware_read_value("$path/class"));
	my $names = hardware_id_names('pci', $vendor, $device,
				      $subvendor, $subdevice);
	my $uevent = hardware_read_uevent("$path/uevent");
	my ($driver, $module) = hardware_driver_info($path);
	$driver ||= $uevent->{'DRIVER'};
	my $name = $names->{'device'} || "PCI $vendor:$device";
	$name = "$names->{'vendor'} $name" if ($names->{'vendor'} &&
						  $name !~ /^\Q$names->{'vendor'}\E\b/i);
	my $class = hardware_pci_class($class_id);
	my @details = (
		[ 'address', $id ],
		[ 'class', $class ],
		[ 'class_id', $class_id ],
		[ 'vendor', hardware_id_label($names->{'vendor'}, $vendor) ],
		[ 'device', hardware_id_label($names->{'device'}, $device) ],
		[ 'subsystem_vendor',
		  hardware_id_label($names->{'subvendor'}, $subvendor) ],
		[ 'subsystem_device',
		  hardware_id_label($names->{'subdevice'}, $subdevice) ],
		[ 'revision', hardware_read_value("$path/revision") ],
		[ 'irq', hardware_read_value("$path/irq") ],
		[ 'numa_node', hardware_read_value("$path/numa_node") ],
		[ 'iommu_group', hardware_link_name("$path/iommu_group") ],
		[ 'local_cpus', hardware_read_value("$path/local_cpulist") ],
		[ 'enabled', hardware_read_value("$path/enable"), 'yesno' ],
		);
	push(@devices, {
		'id' => $id,
		'name' => $name,
		'class' => $class,
		'vendor' => $names->{'vendor'} || uc($vendor),
		'driver' => $driver,
		'module' => $module,
		'modules' => $module ? [ $module ] : [ ],
		'modalias' => $uevent->{'MODALIAS'},
		'details' => \@details,
		'properties' => $uevent,
		});
	}
my @sorted = sort { $a->{'id'} cmp $b->{'id'} } @devices;
return @sorted;
}

# list_usb_devices()
# Enumerates physical USB devices and aggregates drivers from their interfaces.
sub list_usb_devices
{
my $root = "$hardware_sys_root/bus/usb/devices";
my @entries = hardware_directory_entries($root);
my @devices;
foreach my $id (@entries) {
	my $path = "$root/$id";
	my $vendor = hardware_normalize_id(hardware_read_value("$path/idVendor"));
	my $product = hardware_normalize_id(hardware_read_value("$path/idProduct"));
	next if (!$vendor || !$product);
	my $names = hardware_id_names('usb', $vendor, $product);
	my $manufacturer = hardware_read_value("$path/manufacturer");
	my $product_name = hardware_read_value("$path/product");
	my $name = join(" ", grep { defined($_) && $_ ne "" }
				($manufacturer, $product_name));
	$name = join(" ", grep { defined($_) && $_ ne "" }
				($names->{'vendor'}, $names->{'device'})) if (!$name);
	$name ||= "USB $vendor:$product";

	# USB drivers bind to interfaces in most cases, not the parent device.
	my @interfaces;
	foreach my $interface_id (grep { /^\Q$id\E:\d+\.\d+$/ } @entries) {
		my $interface_path = "$root/$interface_id";
		my ($driver, $module) = hardware_driver_info($interface_path);
		my $class_id = hardware_normalize_id(
			hardware_read_value("$interface_path/bInterfaceClass"));
		push(@interfaces, {
			'id' => $interface_id,
			'name' => hardware_read_value("$interface_path/interface"),
			'class' => hardware_usb_class($class_id),
			'class_id' => $class_id,
			'driver' => $driver,
			'module' => $module,
			});
		}
	my ($parent_driver, $parent_module) = hardware_driver_info($path);
	my @drivers = hardware_unique(grep { defined($_) && $_ ne "" }
				($parent_driver, map { $_->{'driver'} } @interfaces));
	my @modules = hardware_unique(grep { defined($_) && $_ ne "" }
				($parent_module, map { $_->{'module'} } @interfaces));
	my $uevent = hardware_read_uevent("$path/uevent");
	my $class_id = hardware_normalize_id(
		hardware_read_value("$path/bDeviceClass"));
	my @details = (
		[ 'location', $id ],
		[ 'bus_number', hardware_read_value("$path/busnum") ],
		[ 'device_number', hardware_read_value("$path/devnum") ],
		[ 'vendor', hardware_id_label(
			$manufacturer || $names->{'vendor'}, $vendor) ],
		[ 'device', hardware_id_label(
			$product_name || $names->{'device'}, $product) ],
		[ 'serial', hardware_read_value("$path/serial") ],
		[ 'usb_version', hardware_read_value("$path/version") ],
		[ 'speed', hardware_read_value("$path/speed"), 'usb_speed' ],
		[ 'class', hardware_usb_class($class_id) ],
		[ 'class_id', $class_id ],
		[ 'protocol', hardware_read_value("$path/bDeviceProtocol") ],
		[ 'removable', hardware_read_value("$path/removable") ],
		[ 'authorized', hardware_read_value("$path/authorized"), 'yesno' ],
		);
	push(@devices, {
		'id' => $id,
		'name' => $name,
		'bus_number' => hardware_read_value("$path/busnum"),
		'device_number' => hardware_read_value("$path/devnum"),
		'speed' => hardware_read_value("$path/speed"),
		'driver' => join(", ", @drivers),
		'module' => @modules == 1 ? $modules[0] : undef,
		'modules' => \@modules,
		'modalias' => $uevent->{'MODALIAS'},
		'interfaces' => \@interfaces,
		'details' => \@details,
		'properties' => $uevent,
		});
	}
my @sorted = sort {
	($a->{'bus_number'} || 0) <=> ($b->{'bus_number'} || 0) ||
	($a->{'device_number'} || 0) <=> ($b->{'device_number'} || 0) ||
	$a->{'id'} cmp $b->{'id'}
	} @devices;
return @sorted;
}

# list_storage_devices()
# Enumerates whole block devices, leaving partitions to disk-management modules.
sub list_storage_devices
{
my $root = "$hardware_sys_root/class/block";
my @devices;
foreach my $id (hardware_directory_entries($root)) {
	my $path = "$root/$id";
	next if (-r "$path/partition");
	my $uevent = hardware_read_uevent("$path/uevent");
	my $sectors = hardware_read_value("$path/size");
	my $size = defined($sectors) && $sectors =~ /^\d+$/ ?
			$sectors * 512 : undef;
	my $vendor = hardware_read_value("$path/device/vendor");
	my $model = hardware_read_value("$path/device/model");
	my $serial = hardware_read_value("$path/device/serial");
	my $name = join(" ", grep { defined($_) && $_ ne "" }
				($vendor, $model));
	$name ||= $id;
	my $target = readlink($path);
	my $virtual = defined($target) && $target =~ m{/virtual/} ? 1 : 0;
	my $removable = hardware_read_value("$path/removable");
	my $rotational = hardware_read_value("$path/queue/rotational");
	my $kind = $virtual ? 'virtual' :
		   $id =~ /^sr\d+$/ ? 'optical' :
		   $removable ? 'removable' :
		   defined($rotational) && !$rotational ? 'ssd' : 'disk';
	my ($driver, $module) = hardware_driver_info("$path/device");
	my $bus_device = hardware_link_name("$path/device");
	my $transport = hardware_link_name("$path/device/subsystem");
	my $firmware = hardware_read_value("$path/device/firmware_rev") ||
		hardware_read_value("$path/device/rev");
	my $wwid = hardware_read_value("$path/wwid") ||
		hardware_read_value("$path/device/wwid");
	my $discard_max = hardware_read_value("$path/queue/discard_max_bytes");
	my $discard = defined($discard_max) && $discard_max =~ /^\d+$/ ?
		($discard_max > 0 ? 1 : 0) : undef;
	my @details = (
		[ 'device_name', "/dev/$id" ],
		[ 'type', $kind, 'storage_type' ],
		[ 'capacity', $size, 'size' ],
		[ 'vendor', $vendor ],
		[ 'model', $model ],
		[ 'serial', $serial ],
		[ 'firmware_revision', $firmware ],
		[ 'wwid', $wwid ],
		[ 'transport', $transport ],
		[ 'bus_device', $bus_device ],
		[ 'state', hardware_read_value("$path/device/state") ],
		[ 'logical_block_size',
		  hardware_read_value("$path/queue/logical_block_size"), 'size' ],
		[ 'physical_block_size',
		  hardware_read_value("$path/queue/physical_block_size"), 'size' ],
		[ 'rotational', $rotational, 'yesno' ],
		[ 'removable', $removable, 'yesno' ],
		[ 'read_only', hardware_read_value("$path/ro"), 'yesno' ],
		[ 'discard', $discard, 'yesno' ],
		[ 'scheduler', hardware_read_value("$path/queue/scheduler") ],
		);
	push(@devices, {
		'id' => $id,
		'name' => $name,
		'model' => $name ne $id ? $name : undef,
		'device' => "/dev/$id",
		'size' => $size,
		'kind' => $kind,
		'driver' => $driver,
		'module' => $module,
		'modules' => $module ? [ $module ] : [ ],
		'modalias' => $uevent->{'MODALIAS'},
		'details' => \@details,
		'properties' => $uevent,
		});
	}
my @sorted = sort { $a->{'id'} cmp $b->{'id'} } @devices;
return @sorted;
}

# list_network_devices()
# Enumerates physical and virtual network interfaces and current link details.
sub list_network_devices
{
my $root = "$hardware_sys_root/class/net";
my @devices;
foreach my $id (hardware_directory_entries($root)) {
	my $path = "$root/$id";
	my $uevent = hardware_read_uevent("$path/uevent");
	my ($driver, $module) = hardware_driver_info("$path/device");
	my $bus_device = hardware_link_name("$path/device");
	my $target = readlink($path);
	my $virtual = !-e "$path/device" ||
		(defined($target) && $target =~ m{/virtual/}) ? 1 : 0;
	my $wireless = -d "$path/wireless" ? 1 : 0;
	my $type_id = hardware_read_value("$path/type");
	my $kind = $wireless ? 'wireless' :
		   $id eq 'lo' ? 'loopback' :
		   $virtual ? 'virtual' :
		   defined($type_id) && $type_id == 1 ? 'ethernet' : 'other';
	my $speed = hardware_read_value("$path/speed");
	$speed = undef if (defined($speed) && $speed !~ /^\d+$/);
	my @details = (
		[ 'interface', $id ],
		[ 'type', $kind, 'network_type' ],
		[ 'address', hardware_read_value("$path/address") ],
		[ 'state', hardware_read_value("$path/operstate") ],
		[ 'carrier', hardware_read_value("$path/carrier"), 'yesno' ],
		[ 'speed', $speed, 'network_speed' ],
		[ 'duplex', hardware_read_value("$path/duplex") ],
		[ 'mtu', hardware_read_value("$path/mtu") ],
		[ 'bus_device', $bus_device ],
		[ 'rx_bytes', hardware_read_value(
			"$path/statistics/rx_bytes"), 'size' ],
		[ 'tx_bytes', hardware_read_value(
			"$path/statistics/tx_bytes"), 'size' ],
		[ 'rx_packets', hardware_read_value(
			"$path/statistics/rx_packets") ],
		[ 'tx_packets', hardware_read_value(
			"$path/statistics/tx_packets") ],
		[ 'rx_errors', hardware_read_value(
			"$path/statistics/rx_errors") ],
		[ 'tx_errors', hardware_read_value(
			"$path/statistics/tx_errors") ],
		[ 'rx_dropped', hardware_read_value(
			"$path/statistics/rx_dropped") ],
		[ 'tx_dropped', hardware_read_value(
			"$path/statistics/tx_dropped") ],
		);
	push(@devices, {
		'id' => $id,
		'name' => $id,
		'kind' => $kind,
		'address' => hardware_read_value("$path/address"),
		'state' => hardware_read_value("$path/operstate"),
		'speed' => $speed,
		'driver' => $driver,
		'module' => $module,
		'modules' => $module ? [ $module ] : [ ],
		'modalias' => $uevent->{'MODALIAS'},
		'details' => \@details,
		'properties' => $uevent,
		});
	}
my @sorted = sort {
	$a->{'id'} eq 'lo' ? -1 :
	$b->{'id'} eq 'lo' ? 1 : $a->{'id'} cmp $b->{'id'}
	} @devices;
return @sorted;
}

# list_sensor_devices()
# Enumerates standard hwmon readings without invoking the sensors command.
sub list_sensor_devices
{
my $root = "$hardware_sys_root/class/hwmon";
my @devices;
foreach my $hwmon (hardware_directory_entries($root)) {
	my $path = "$root/$hwmon";
	my $chip = hardware_read_value("$path/name") || $hwmon;
	my ($driver, $module) = hardware_driver_info("$path/device");
	my $uevent = hardware_read_uevent("$path/device/uevent");
	foreach my $entry (hardware_directory_entries($path, 1)) {
		next if ($entry !~ /^(temp|fan|in|curr|power)(\d+)_input$/);
		my ($kind, $number) = ($1, $2);
		my $raw = hardware_read_value("$path/$entry");
		my $reading = hardware_sensor_reading($kind, $raw);
		next if (!defined($reading));
		my $label = hardware_read_value(
			"$path/${kind}${number}_label") ||
			text('sensor_numbered', $text{"sensor_$kind"}, $number);
		my $id = "$hwmon:$kind$number";
		my @details = (
			[ 'sensor_chip', $chip ],
			[ 'sensor_type', $text{"sensor_$kind"} ],
			[ 'sensor_reading', $reading ],
			[ 'location', $id ],
			);
		push(@devices, {
			'id' => $id,
			'name' => $label,
			'chip' => $chip,
			'kind' => $kind,
			'reading' => $reading,
			'driver' => $driver,
			'module' => $module,
			'modules' => $module ? [ $module ] : [ ],
			'modalias' => $uevent->{'MODALIAS'},
			'details' => \@details,
			'properties' => $uevent,
			});
		}
	}
my @sorted = sort {
		$a->{'chip'} cmp $b->{'chip'} || $a->{'id'} cmp $b->{'id'}
		} @devices;
return @sorted;
}

# hardware_sensor_reading(kind, raw-value)
# Converts Linux hwmon base units into concise human-readable readings.
sub hardware_sensor_reading
{
my ($kind, $raw) = @_;
return if (!defined($raw) || $raw !~ /^-?\d+$/);
my %scale = (
	'temp' => [ 1000, 'format_celsius' ],
	'fan' => [ 1, 'format_rpm' ],
	'in' => [ 1000, 'format_volts' ],
	'curr' => [ 1000, 'format_amps' ],
	'power' => [ 1000000, 'format_watts' ],
	);
return if (!$scale{$kind});
my $divisor = $scale{$kind}->[0];
my $half = int($divisor / 2);
my $scaled = $raw * 100 + ($raw < 0 ? -$half : $half);
my $hundredths = int($scaled / $divisor);
my $absolute = abs($hundredths);
my $number = ($hundredths < 0 ? "-" : "").
	int($absolute / 100).".".sprintf("%02d", $absolute % 100);
$number =~ s/\.?0+$//;
return text($scale{$kind}->[1], $number);
}

# list_cpu_devices()
# Enumerates logical processors from procfs and augments them with sysfs state.
sub list_cpu_devices
{
my $data = hardware_read_file("$hardware_proc_root/cpuinfo");
my @records;
my %shared;
if (defined($data)) {
	foreach my $block (split(/\n\s*\n/, $data)) {
		my %record;
		foreach my $line (split(/\r?\n/, $block)) {
			if ($line =~ /^([^:]+?)\s*:\s*(.*)$/) {
				my ($key, $value) = (lc($1), $2);
				$key =~ s/^\s+|\s+$//g;
				$record{$key} = $value;
				}
			}
		if (defined($record{'processor'}) &&
		    $record{'processor'} =~ /^\d+$/) {
			push(@records, \%record);
			}
		else {
			%shared = (%shared, %record);
			}
		}
	}

# Some architectures provide sparse cpuinfo records, so sysfs is the fallback.
if (!@records) {
	foreach my $entry (hardware_directory_entries(
				"$hardware_sys_root/devices/system/cpu")) {
		next if ($entry !~ /^cpu(\d+)$/);
		push(@records, { 'processor' => $1 });
		}
	}

my @devices;
my $index = 0;
foreach my $record (@records) {
	my $id = defined($record->{'processor'}) ? $record->{'processor'} : $index;
	next if ($id !~ /^\d+$/);
	my $path = "$hardware_sys_root/devices/system/cpu/cpu$id";
	my $model = hardware_cpu_model($record, \%shared, $id);
	my $socket = defined($record->{'physical id'}) ?
		$record->{'physical id'} :
		hardware_read_value("$path/topology/physical_package_id");
	$socket = hardware_topology_id($socket);
	my $core = defined($record->{'core id'}) ? $record->{'core id'} :
		hardware_read_value("$path/topology/core_id");
	$core = hardware_topology_id($core);
	my $online = hardware_read_value("$path/online");
	$online = 1 if (!defined($online));
	my $frequency = hardware_read_value(
		"$path/cpufreq/scaling_cur_freq");
	$frequency = $frequency / 1000
		if (defined($frequency) && $frequency =~ /^\d+$/);
	$frequency ||= $record->{'cpu mhz'};
	my $frequency_driver = hardware_read_value(
		"$path/cpufreq/scaling_driver");
	my @details = (
		[ 'processor', $id ],
		[ 'model', $model ],
		[ 'vendor', $record->{'vendor_id'} || $record->{'cpu implementer'} ],
		[ 'socket', $socket ],
		[ 'core', $core ],
		[ 'online', $online, 'yesno' ],
		[ 'frequency', $frequency, 'cpu_frequency' ],
		[ 'frequency_driver', $frequency_driver ],
		[ 'cpu_family', $record->{'cpu family'} ],
		[ 'model_id', $record->{'model'} ],
		[ 'stepping', $record->{'stepping'} ],
		[ 'microcode', $record->{'microcode'} ],
		[ 'cache', $record->{'cache size'} ],
		[ 'siblings', $record->{'siblings'} ],
		[ 'cpu_cores', $record->{'cpu cores'} ],
		[ 'bogomips', $record->{'bogomips'} ],
		[ 'flags', $record->{'flags'} || $record->{'features'} ],
		);
	push(@devices, {
		'id' => "$id",
		'name' => "CPU $id",
		'model' => $model,
		'socket' => $socket,
		'core' => $core,
		'online' => $online,
		'frequency' => $frequency,
		'driver' => $frequency_driver,
		'modules' => [ ],
		'details' => \@details,
		'properties' => { },
		});
	$index++;
	}
my @sorted = sort { $a->{'id'} <=> $b->{'id'} } @devices;
return @sorted;
}

# hardware_cpu_model(record, shared-record, id)
# Selects an architecture-neutral CPU name without treating a numeric ID as one.
sub hardware_cpu_model
{
my ($record, $shared, $id) = @_;
foreach my $key ('model name', 'processor name', 'cpu model', 'cpu', 'uarch') {
	my $value = $record->{$key};
	return $value if (defined($value) && $value ne "" &&
			  $value !~ /^\d+$/);
	}
if ($record->{'cpu implementer'} || $record->{'cpu part'} ||
    $record->{'cpu architecture'}) {
	my $architecture = $record->{'cpu architecture'};
	my $model = defined($architecture) && $architecture =~ /^\d+$/ ?
		"ARMv$architecture processor" : "ARM processor";
	my @ids;
	push(@ids, "implementer $record->{'cpu implementer'}")
		if ($record->{'cpu implementer'});
	push(@ids, "part $record->{'cpu part'}") if ($record->{'cpu part'});
	return $model.(@ids ? " (".join(", ", @ids).")" : "");
	}
foreach my $source ($record, $shared) {
	foreach my $key ('model name', 'processor name', 'cpu model', 'cpu',
			 'uarch', 'processor', 'hardware', 'machine', 'model') {
		my $value = $source->{$key};
		return $value if (defined($value) && $value ne "" &&
				  $value !~ /^\d+$/);
		}
	}
return "CPU $id";
}

# hardware_topology_id(value)
# Keeps usable kernel topology identifiers and drops negative unknown values.
sub hardware_topology_id
{
my ($value) = @_;
return if (!defined($value) || $value !~ /^-?\d+$/ || $value < 0);
return $value;
}

# hardware_kernel_module(name)
# Returns metadata for one loaded module. Kernel section addresses are omitted.
sub hardware_kernel_module
{
my ($name) = @_;
return if (!defined($name) || $name !~ /^[A-Za-z0-9][A-Za-z0-9_+-]*$/);
my $path = "$hardware_sys_root/module/$name";
return if (!-d $path);
my $module = {
	'name' => $name,
	'state' => hardware_read_value("$path/initstate"),
	'refcount' => hardware_read_value("$path/refcnt"),
	'taint' => hardware_read_value("$path/taint"),
	'version' => hardware_read_value("$path/version"),
	'srcversion' => hardware_read_value("$path/srcversion"),
	'coresize' => hardware_read_value("$path/coresize"),
	'initsize' => hardware_read_value("$path/initsize"),
	};
my @holders = hardware_directory_entries("$path/holders");
$module->{'holders'} = \@holders;
my %parameters;
foreach my $parameter (hardware_directory_entries("$path/parameters", 1)) {
	next if ($parameter !~ /^[A-Za-z0-9_+.-]+$/);
	my $value = hardware_read_value("$path/parameters/$parameter");
	$parameters{$parameter} = $value if (defined($value));
	}
$module->{'parameters'} = \%parameters;

# modinfo adds package metadata when kmod is installed, but is not required.
my $modinfo = defined($hardware_modinfo_command) ?
	$hardware_modinfo_command : has_command("modinfo");
if ($modinfo) {
	my $out = backquote_command(quotemeta($modinfo)." ".
				quotemeta($name)." 2>/dev/null", 1);
	if (!$? && defined($out)) {
		my %info;
		foreach my $line (split(/\r?\n/, $out)) {
			next if ($line !~ /^(\w[\w-]*):\s*(.*)$/);
			my ($key, $value) = (lc($1), $2);
			if (defined($info{$key}) && $info{$key} ne "") {
				$info{$key} .= ", ".$value;
				}
			else {
				$info{$key} = $value;
				}
			}
		$module->{'modinfo'} = \%info;
		}
	}
return $module;
}

# hardware_driver_info(path)
# Returns the bound driver and its loadable module, if either is exposed.
sub hardware_driver_info
{
my ($path) = @_;
my @paths = ($path);
my $resolved = abs_path($path);
my $sysroot = abs_path($hardware_sys_root);
if ($resolved && $sysroot &&
    ($resolved eq $sysroot || $resolved =~ /^\Q$sysroot\E\//)) {
	# Some devices, notably NVMe namespaces, inherit the useful driver from
	# a controller ancestor instead of exposing a driver link themselves.
	my $current = $resolved;
	for (my $depth = 0; $depth < 8 && $current ne $sysroot; $depth++) {
		push(@paths, $current) if ($current ne $path);
		$current =~ s{/[^/]+$}{};
		}
	}
foreach my $candidate (@paths) {
	my $driver = hardware_link_name("$candidate/driver");
	next if (!$driver);
	return ($driver, hardware_link_name("$candidate/driver/module"));
	}
return (undef, undef);
}

# hardware_link_name(path)
# Returns the last component of a symlink target.
sub hardware_link_name
{
my ($path) = @_;
my $target = readlink($path);
return if (!defined($target));
$target =~ s{/+$}{};
return $1 if ($target =~ m{([^/]+)$});
return;
}

# hardware_read_uevent(file)
# Parses a sysfs uevent file into its uppercase key/value properties.
sub hardware_read_uevent
{
my ($file) = @_;
my $data = hardware_read_file($file);
my %values;
return \%values if (!defined($data));
foreach my $line (split(/\r?\n/, $data)) {
	if ($line =~ /^([A-Z][A-Z0-9_]*)=(.*)$/) {
		$values{$1} = $2;
		}
	}
return \%values;
}

# hardware_read_file(file)
# Reads a fixed inventory file and returns undef when it is unavailable.
sub hardware_read_file
{
my ($file) = @_;
return if (!-r $file || -d $file);
return read_file_contents($file);
}

# hardware_read_value(file)
# Reads a small sysfs/procfs value and removes surrounding whitespace.
sub hardware_read_value
{
my ($file) = @_;
my $value = hardware_read_file($file);
return if (!defined($value));
$value =~ s/\0//g;
$value =~ s/^\s+|\s+$//g;
return $value;
}

# hardware_directory_entries(directory, [include-files])
# Returns safe directory entry names without following user-provided paths.
sub hardware_directory_entries
{
my ($directory, $include_files) = @_;
return ( ) if (!-d $directory);
opendir(my $dir, $directory) || return ( );
my @entries = grep {
	$_ ne '.' && $_ ne '..' &&
	($include_files || -d "$directory/$_")
	} readdir($dir);
closedir($dir);
my @sorted = sort @entries;
return @sorted;
}

# hardware_normalize_id(value)
# Converts sysfs hexadecimal IDs to lowercase values without the 0x prefix.
sub hardware_normalize_id
{
my ($value) = @_;
return if (!defined($value));
$value =~ s/^0x//i;
return lc($value) if ($value =~ /^[0-9a-f]+$/i);
return;
}

# hardware_id_label(name, id)
# Combines a friendly database name with the hexadecimal hardware ID.
sub hardware_id_label
{
my ($name, $id) = @_;
return if (!defined($id) || $id eq "");
return defined($name) && $name ne "" ? "$name ($id)" : uc($id);
}

# hardware_id_names(kind, vendor, device, [subvendor], [subdevice])
# Looks up friendly names in the optional pci.ids or usb.ids database.
sub hardware_id_names
{
my ($kind, $vendor, $device, $subvendor, $subdevice) = @_;
my $database = hardware_load_id_database($kind);
my %names = (
	'vendor' => $database->{'vendors'}->{$vendor},
	'device' => $database->{'devices'}->{"$vendor:$device"},
	);
if ($kind eq 'pci' && $subvendor && $subdevice) {
	$names{'subvendor'} = $database->{'vendors'}->{$subvendor};
	$names{'subdevice'} = $database->{'subdevices'}->{
		"$vendor:$device:$subvendor:$subdevice"} ||
		$database->{'devices'}->{"$subvendor:$subdevice"};
	}
return \%names;
}

# hardware_load_id_database(kind)
# Loads only vendor, device and PCI subsystem names from a standard IDs file.
sub hardware_load_id_database
{
my ($kind) = @_;
my $file = hardware_id_database_file($kind);
return { 'vendors' => { }, 'devices' => { }, 'subdevices' => { } }
	if (!$file);
return $hardware_ids_cache{"$kind:$file"}
	if ($hardware_ids_cache{"$kind:$file"});
my $database = { 'vendors' => { }, 'devices' => { },
			 'subdevices' => { } };
open(my $ids, '<', $file) || return $database;
my ($vendor, $device);
while (my $line = <$ids>) {
	$line =~ s/\r?\n$//;
	if ($kind eq 'pci' && $line =~ /^\t\t([0-9a-f]{4})\s+([0-9a-f]{4})\s+(.+)/i &&
	    defined($vendor) && defined($device)) {
		$database->{'subdevices'}->{lc("$vendor:$device:$1:$2")} = $3;
		}
	elsif ($line =~ /^\t([0-9a-f]{4})\s+(.+)/i && defined($vendor)) {
		$device = lc($1);
		$database->{'devices'}->{"$vendor:$device"} = $2;
		}
	elsif ($line =~ /^([0-9a-f]{4})\s+(.+)/i) {
		$vendor = lc($1);
		$device = undef;
		$database->{'vendors'}->{$vendor} = $2;
		}
	elsif ($line !~ /^\t/) {
		$vendor = undef;
		$device = undef;
		}
	}
close($ids);
$hardware_ids_cache{"$kind:$file"} = $database;
return $database;
}

# hardware_id_database_file(kind)
# Finds a distribution's standard PCI or USB ID database.
sub hardware_id_database_file
{
my ($kind) = @_;
my $configured = $kind eq 'pci' ? $hardware_pci_ids_file :
					 $hardware_usb_ids_file;
return $configured if ($configured && -r $configured);
my @paths = $kind eq 'pci' ?
	('/usr/share/hwdata/pci.ids', '/usr/share/misc/pci.ids',
	 '/usr/share/pci.ids') :
	('/usr/share/hwdata/usb.ids', '/usr/share/misc/usb.ids',
	 '/var/lib/usbutils/usb.ids', '/usr/share/usb.ids');
foreach my $file (@paths) {
	return $file if (-r $file);
	}
return;
}

# hardware_pci_class(class-id)
# Returns a friendly name for the PCI base class.
sub hardware_pci_class
{
my ($class_id) = @_;
my $base = defined($class_id) ? substr($class_id, 0, 2) : "";
return $text{"pci_class_$base"} || $text{'pci_class_other'} ||
	'Other PCI device';
}

# hardware_usb_class(class-id)
# Returns a friendly name for a USB device or interface class.
sub hardware_usb_class
{
my ($class_id) = @_;
my $key = $class_id || "";
return $text{"usb_class_$key"} || $text{'usb_class_other'} ||
	'Other USB device';
}

# hardware_chassis_type_name(type-id)
# Translates useful SMBIOS chassis identifiers and omits unknown placeholders.
sub hardware_chassis_type_name
{
my ($type) = @_;
return if (!defined($type) || $type eq "" || $type eq '1' || $type eq '2');
return $text{"chassis_type_$type"} || text('chassis_type_other', $type)
	if ($type =~ /^\d+$/);
return $type;
}

# hardware_number(value)
# Formats a measured decimal without unnecessary trailing zeroes.
sub hardware_number
{
my ($value) = @_;
return "" if (!defined($value) || $value !~ /^\d+(?:\.\d+)?$/);
my $number = sprintf("%.2f", $value);
$number =~ s/\.?0+$//;
return $number;
}

# hardware_unique(values)
# Returns non-empty values once, retaining their original order.
sub hardware_unique
{
my %seen;
return grep { defined($_) && $_ ne "" && !$seen{$_}++ } @_;
}

1;
