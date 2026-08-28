#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

# script_dir()
# Returns the directory containing this test file.
sub script_dir
{
my $path = $0;
if ($path =~ m{^/}) {
	$path =~ s{/[^/]+$}{};
	return $path;
	}
my $cwd = `pwd`;
chomp($cwd);
if ($path =~ m{/}) {
	$path =~ s{/[^/]+$}{};
	return $cwd.'/'.$path;
	}
return $cwd;
}

# write_test_file(file, data)
# Creates a fixture file and any missing parent directories.
sub write_test_file
{
my ($file, $data) = @_;
my $directory = $file;
$directory =~ s{/[^/]+$}{};
make_path($directory) if (!-d $directory);
open(my $fh, '>', $file) or die "$file: $!";
print $fh $data;
close($fh);
}

# slurp_test_file(file)
# Reads a source file for structural UI assertions.
sub slurp_test_file
{
my ($file) = @_;
open(my $fh, '<', $file) or die "$file: $!";
local $/;
my $data = <$fh>;
close($fh);
return $data;
}

my $bindir = script_dir();
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";
my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
write_test_file("$confdir/config",
	"os_type=generic-linux\nos_version=0\n".
	"real_os_type=Test Linux\nreal_os_version=1\n");
write_test_file("$confdir/var-path", "$vardir\n");
$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'hardware-info';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";
require './hardware-info-lib.pl'; ## no critic

our ($hardware_sys_root, $hardware_proc_root, $hardware_pci_ids_file,
     $hardware_usb_ids_file, $hardware_modinfo_command);
our %hardware_ids_cache;

my $fixture = tempdir(CLEANUP => 1);
$hardware_sys_root = "$fixture/sys";
$hardware_proc_root = "$fixture/proc";
$hardware_pci_ids_file = "$fixture/pci.ids";
$hardware_usb_ids_file = "$fixture/usb.ids";
$hardware_modinfo_command = '';
%hardware_ids_cache = ( );

# Create friendly-name databases used by the PCI and USB inventory parsers.
write_test_file($hardware_pci_ids_file,
	"8086  Intel Corporation\n".
	"\t15f3  Ethernet Controller\n".
	"\t\t1a2b 3c4d  Server Ethernet Adapter\n".
	"1a2b  Example Systems\n".
	"\t3c4d  Server Ethernet Adapter\n");
write_test_file($hardware_usb_ids_file,
	"046d  Example Peripherals\n".
	"\tc534  USB Receiver\n");

# Build a PCI function with an e1000e driver/module binding.
my $pci = "$hardware_sys_root/bus/pci/devices/0000:00:1f.6";
my $pci_driver = "$hardware_sys_root/bus/pci/drivers/e1000e";
my $module = "$hardware_sys_root/module/e1000e";
my $iommu_group = "$hardware_sys_root/kernel/iommu_groups/12";
make_path($pci, $pci_driver, $module, $iommu_group);
write_test_file("$pci/vendor", "0x8086\n");
write_test_file("$pci/device", "0x15f3\n");
write_test_file("$pci/subsystem_vendor", "0x1a2b\n");
write_test_file("$pci/subsystem_device", "0x3c4d\n");
write_test_file("$pci/class", "0x020000\n");
write_test_file("$pci/revision", "0x03\n");
write_test_file("$pci/irq", "16\n");
write_test_file("$pci/uevent",
	"DRIVER=e1000e\nPCI_SLOT_NAME=0000:00:1f.6\n".
	"MODALIAS=pci:test\n");
symlink($pci_driver, "$pci/driver") or die "pci driver symlink: $!";
symlink($module, "$pci_driver/module") or die "pci module symlink: $!";
symlink($iommu_group, "$pci/iommu_group") or die "iommu symlink: $!";

# Build a USB parent whose HID driver is bound to its interface.
my $usb = "$hardware_sys_root/bus/usb/devices/1-2";
my $usb_interface = "$hardware_sys_root/bus/usb/devices/1-2:1.0";
my $usb_driver = "$hardware_sys_root/bus/usb/drivers/usbhid";
my $usb_module = "$hardware_sys_root/module/usbhid";
make_path($usb, $usb_interface, $usb_driver, $usb_module);
write_test_file("$usb/idVendor", "046d\n");
write_test_file("$usb/idProduct", "c534\n");
write_test_file("$usb/manufacturer", "Example Peripherals\n");
write_test_file("$usb/product", "USB Receiver\n");
write_test_file("$usb/busnum", "1\n");
write_test_file("$usb/devnum", "4\n");
write_test_file("$usb/speed", "480\n");
write_test_file("$usb/bDeviceClass", "00\n");
write_test_file("$usb/uevent", "PRODUCT=46d/c534/2900\n");
write_test_file("$usb_interface/bInterfaceClass", "03\n");
write_test_file("$usb_interface/interface", "Keyboard\n");
symlink($usb_driver, "$usb_interface/driver") or die "usb driver symlink: $!";
symlink($usb_module, "$usb_driver/module") or die "usb module symlink: $!";

# Build one solid-state block device backed by the sd_mod module.
my $disk = "$hardware_sys_root/class/block/sda";
my $disk_driver = "$hardware_sys_root/bus/scsi/drivers/sd";
my $disk_module = "$hardware_sys_root/module/sd_mod";
make_path("$disk/device", "$disk/queue", $disk_driver, $disk_module);
write_test_file("$disk/size", "2097152\n");
write_test_file("$disk/removable", "0\n");
write_test_file("$disk/ro", "0\n");
write_test_file("$disk/device/vendor", "ATA\n");
write_test_file("$disk/device/model", "Fixture SSD\n");
write_test_file("$disk/device/serial", "DISK123\n");
write_test_file("$disk/device/firmware_rev", "FW1.2\n");
write_test_file("$disk/wwid", "naa.5000123456789abc\n");
write_test_file("$disk/queue/rotational", "0\n");
write_test_file("$disk/queue/logical_block_size", "512\n");
write_test_file("$disk/queue/physical_block_size", "4096\n");
write_test_file("$disk/queue/discard_max_bytes", "1048576\n");
write_test_file("$disk/uevent", "DEVNAME=sda\nDEVTYPE=disk\n");
symlink($disk_driver, "$disk/device/driver") or die "disk driver symlink: $!";
symlink($disk_module, "$disk_driver/module") or die "disk module symlink: $!";
symlink("$hardware_sys_root/bus/scsi", "$disk/device/subsystem") or
	die "disk subsystem symlink: $!";

# Build a physical Ethernet interface and its current counters.
my $net = "$hardware_sys_root/class/net/eth0";
my $net_driver = "$hardware_sys_root/bus/pci/drivers/igb";
my $net_module = "$hardware_sys_root/module/igb";
make_path("$net/device", "$net/statistics", $net_driver, $net_module);
write_test_file("$net/type", "1\n");
write_test_file("$net/address", "00:11:22:33:44:55\n");
write_test_file("$net/operstate", "up\n");
write_test_file("$net/speed", "1000\n");
write_test_file("$net/mtu", "1500\n");
write_test_file("$net/statistics/rx_bytes", "4096\n");
write_test_file("$net/statistics/tx_bytes", "2048\n");
write_test_file("$net/uevent", "INTERFACE=eth0\n");
symlink($net_driver, "$net/device/driver") or die "net driver symlink: $!";
symlink($net_module, "$net_driver/module") or die "net module symlink: $!";

# Build standard hwmon temperature and fan readings.
my $hwmon = "$hardware_sys_root/class/hwmon/hwmon0";
make_path($hwmon);
write_test_file("$hwmon/name", "fixture_hwmon\n");
write_test_file("$hwmon/temp1_label", "CPU package\n");
write_test_file("$hwmon/temp1_input", "42500\n");
write_test_file("$hwmon/fan1_label", "System fan\n");
write_test_file("$hwmon/fan1_input", "1800\n");

# Build two logical processors and system-level memory/DMI fields.
write_test_file("$hardware_proc_root/cpuinfo", <<'EOF');
processor : 0
vendor_id : GenuineFixture
model name : Fixture CPU 3.00GHz
physical id : 0
core id : 0
cpu MHz : 3000.000
flags : fpu sse

processor : 1
vendor_id : GenuineFixture
model name : Fixture CPU 3.00GHz
physical id : 0
core id : 1
cpu MHz : 2800.000
flags : fpu sse
EOF
write_test_file("$hardware_proc_root/meminfo", "MemTotal:       8388608 kB\n");
write_test_file("$hardware_sys_root/class/dmi/id/sys_vendor", "Fixture Inc.\n");
write_test_file("$hardware_sys_root/class/dmi/id/product_name", "Test Server\n");
write_test_file("$hardware_sys_root/class/dmi/id/product_serial", "SYS123\n");
write_test_file("$hardware_sys_root/class/dmi/id/chassis_type", "23\n");
my $secure_boot_var = "$hardware_sys_root/firmware/efi/efivars/".
	"SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c";
write_test_file($secure_boot_var, pack("V C", 7, 1));
make_path("$hardware_sys_root/class/tpm/tpm0");

# Populate metadata and parameters for the linked e1000e module page.
write_test_file("$module/initstate", "live\n");
write_test_file("$module/refcnt", "1\n");
write_test_file("$module/version", "1.2.3\n");
write_test_file("$module/coresize", "65536\n");
write_test_file("$module/parameters/InterruptThrottleRate", "3\n");
make_path("$module/holders");

my @pci_devices = list_pci_devices();
is(scalar(@pci_devices), 1, 'one PCI function is enumerated');
is($pci_devices[0]->{'name'}, 'Intel Corporation Ethernet Controller',
	'PCI database names are applied');
is($pci_devices[0]->{'class'}, 'Network controller',
	'PCI base class is translated');
is($pci_devices[0]->{'driver'}, 'e1000e', 'PCI driver is resolved');
is($pci_devices[0]->{'module'}, 'e1000e', 'PCI kernel module is resolved');
my %pci_details = map { $_->[0], $_->[1] } @{$pci_devices[0]->{'details'}};
is($pci_details{'iommu_group'}, '12', 'PCI IOMMU group is retained');

my @usb_devices = list_usb_devices();
is(scalar(@usb_devices), 1, 'USB interfaces are not duplicated as devices');
is($usb_devices[0]->{'driver'}, 'usbhid',
	'USB interface driver is aggregated into parent');
is_deeply($usb_devices[0]->{'modules'}, [ 'usbhid' ],
	'USB interface module is aggregated into parent');
is($usb_devices[0]->{'interfaces'}->[0]->{'class'},
	'Human interface device', 'USB interface class is translated');

my @storage = list_storage_devices();
is(scalar(@storage), 1, 'one whole block device is enumerated');
is($storage[0]->{'size'}, 1024 * 1024 * 1024,
	'block sectors are converted to bytes');
is($storage[0]->{'kind'}, 'ssd', 'non-rotational disk is an SSD');
is($storage[0]->{'module'}, 'sd_mod', 'storage module is resolved');
is($storage[0]->{'device'}, '/dev/sda', 'storage device file is retained');
is($storage[0]->{'model'}, 'ATA Fixture SSD',
	'storage model remains separate from its device file');
my %storage_details = map { $_->[0], $_->[1] }
	@{$storage[0]->{'details'}};
is($storage_details{'firmware_revision'}, 'FW1.2',
	'storage firmware revision is retained');
is($storage_details{'wwid'}, 'naa.5000123456789abc',
	'storage WWID is retained');
is($storage_details{'transport'}, 'scsi',
	'storage transport is resolved');
is($storage_details{'discard'}, 1, 'storage discard support is detected');

my @network = list_network_devices();
is(scalar(@network), 1, 'one network interface is enumerated');
is($network[0]->{'kind'}, 'ethernet', 'physical ARPHRD interface is Ethernet');
is($network[0]->{'speed'}, '1000', 'network link speed is read');
is($network[0]->{'module'}, 'igb', 'network module is resolved');

my @sensors = list_sensor_devices();
is(scalar(@sensors), 2, 'standard hwmon readings are enumerated');
is($sensors[0]->{'reading'}, '1800 RPM', 'fan reading keeps its base unit');
is($sensors[1]->{'reading'}, '42.5 °C',
	'temperature reading is converted from millidegrees');
is(hardware_sensor_reading('in', '11895'), '11.9 V',
	'voltage reading is converted from millivolts');
is(hardware_sensor_reading('curr', '1500'), '1.5 A',
	'current reading is converted from milliamps');
is(hardware_sensor_reading('power', '9706000'), '9.71 W',
	'power reading is converted from microwatts');
ok(!defined(hardware_sensor_reading('temp', 'unavailable')),
	'invalid hwmon readings are omitted');

my @cpus = list_cpu_devices();
is(scalar(@cpus), 2, 'logical processors are enumerated');
is($cpus[1]->{'core'}, '1', 'processor topology is retained');
is($cpus[0]->{'model'}, 'Fixture CPU 3.00GHz', 'processor model is retained');

my $summary = hardware_system_summary(\@cpus);
is($summary->{'system_vendor'}, 'Fixture Inc.', 'DMI vendor is summarized');
is($summary->{'system_product'}, 'Test Server', 'DMI product is summarized');
is($summary->{'memory'}, 8 * 1024 * 1024 * 1024,
	'usable memory is converted to bytes');
is($summary->{'cpu_count'}, 2, 'logical processor count is summarized');
is($summary->{'cpu_sockets'}, 1, 'physical package count is summarized');
is($summary->{'firmware_mode'}, 'uefi', 'UEFI firmware is detected');
is($summary->{'secure_boot'}, 1, 'UEFI Secure Boot state is read');
is_deeply($summary->{'tpms'}, [ 'tpm0' ], 'TPM presence is reported');
is(hardware_chassis_type_name($summary->{'chassis_type'}),
	'Rack-mount chassis', 'SMBIOS chassis type is translated');
ok(!defined(hardware_chassis_type_name('2')),
	'unknown SMBIOS chassis placeholder is omitted');

# ARM cpuinfo commonly exposes IDs without a friendly model on every record.
{
	local $hardware_proc_root = "$fixture/arm-proc";
	local $hardware_sys_root = "$fixture/arm-sys";
	my $arm_cpuinfo = "";
	foreach my $id (0 .. 3) {
		$arm_cpuinfo .= "processor : $id\n".
			"BogoMIPS : 60.00\n".
			"CPU implementer : 0x41\n".
			"CPU architecture : 8\n".
			"CPU part : 0xd0c\n\n";
		write_test_file("$hardware_sys_root/devices/system/cpu/cpu$id/".
			"topology/physical_package_id", "60\n");
		write_test_file("$hardware_sys_root/devices/system/cpu/cpu$id/".
			"topology/core_id", "$id\n");
		}
	write_test_file("$hardware_proc_root/cpuinfo", $arm_cpuinfo);
	my @arm_cpus = list_cpu_devices();
	is(scalar(@arm_cpus), 4, 'ARM logical processors are enumerated');
	is($arm_cpus[0]->{'model'},
		'ARMv8 processor (implementer 0x41, part 0xd0c)',
		'ARM CPU identity does not fall back to its numeric processor ID');
	is($arm_cpus[3]->{'model'}, $arm_cpus[0]->{'model'},
		'ARM processor model is consistent across logical CPUs');
	is($arm_cpus[0]->{'socket'}, '60',
		'kernel package identifiers are retained without implying a socket number');
	my $arm_summary = hardware_system_summary(\@arm_cpus);
	is_deeply($arm_summary->{'cpu_models'}, [ $arm_cpus[0]->{'model'} ],
		'ARM summary contains one accurate processor model');
	is($arm_summary->{'cpu_sockets'}, 1,
		'ARM package count uses unique kernel package identifiers');
}

my $module_info = hardware_kernel_module('e1000e');
is($module_info->{'state'}, 'live', 'loaded module state is read');
is($module_info->{'coresize'}, '65536', 'loaded module size is read');
is($module_info->{'parameters'}->{'InterruptThrottleRate'}, '3',
	'loaded module parameters are read');

# Read-only Webmin users may run modinfo because it only reports metadata.
my ($modinfo_safe, $safe_module_info);
{
	no warnings 'redefine';
	local *backquote_command = sub {
		$modinfo_safe = $_[1];
		$? = 0;
		return "description: Fixture driver\n";
		};
	local $hardware_modinfo_command = '/usr/sbin/modinfo';
	$safe_module_info = hardware_kernel_module('e1000e');
}
is($modinfo_safe, 1, 'modinfo lookup is allowed in Webmin read-only mode');
is($safe_module_info->{'modinfo'}->{'description'}, 'Fixture driver',
	'modinfo metadata is retained for read-only users');

ok(get_hardware_device('pci', '0000:00:1f.6'),
	'exact enumerated device IDs can be selected');
ok(!get_hardware_device('pci', '../module/e1000e'),
	'device selection does not accept paths');
ok(!get_hardware_device('unknown', '0000:00:1f.6'),
	'unknown device groups are rejected');
ok(!hardware_kernel_module('../e1000e'),
	'kernel module selection does not accept paths');
ok(!hardware_kernel_module('..'),
	'kernel module selection does not accept parent directory names');
ok(!hardware_kernel_module('not_loaded'),
	'unloaded module names are rejected');

# The index presents its summary as a peer tab and describes every tab.
my $index_source = slurp_test_file("$bindir/../index.cgi");
like($index_source,
	qr/\[\s*'system'\s*,\s*\$text\{'type_system'\}\s*\]/,
	'system report is an index tab');
like($index_source,
	qr/\$text\{"type_\$_"\}\.\s*'&nbsp;'\.\s*ui_tag\('sup',/s,
	'inventory tab counts use superscript markup');
unlike($index_source, qr/text\('index_tab'/,
	'inventory tab counts do not use parenthesized labels');
like($index_source,
	qr/foreach my \$tab \('system', \@types\).*?print ui_div\(\$text\{"index_\$\{tab\}_desc"\}\)/s,
	'every index tab renders its description');
like($index_source,
	qr/if \(\$tab eq 'system'\).*?print_system_summary\(\$summary\)/s,
	'system summary is rendered inside its tab');
like($index_source,
	qr/my \@types = grep \{ \$_ ne 'sensor' \|\| \@\{\$devices\{\$_\}\} \}/,
	'sensor tab is omitted when no readings are available');
like($index_source,
	qr/hardware_device_link\('storage', \$device, \$device->\{'device'\}\)/,
	'storage table identifies devices by their device files');
like($index_source,
	qr/ui_print_header\([^;]*"intro"\s*,\s*0\s*,\s*1\s*\);/s,
	'index keeps module help but disables the configuration action');

# Detail pages keep one general table and one expandable supplementary panel,
# without repeating the index-only help and configuration actions.
my $view_source = slurp_test_file("$bindir/../view.cgi");
my $module_source = slurp_test_file("$bindir/../module.cgi");
my @view_tables = $view_source =~ /\bui_table_start\(/g;
my @view_hidden = $view_source =~ /\bui_hidden_table_start\(/g;
my @module_tables = $module_source =~ /\bui_table_start\(/g;
my @module_hidden = $module_source =~ /\bui_hidden_table_start\(/g;
is(scalar(@view_tables), 1, 'device page has one general information table');
is(scalar(@view_hidden), 1, 'device page has one supplementary panel');
like($view_source,
	qr/ui_hidden_table_start\([^;]*"driver_properties"\s*,\s*1\s*,/s,
	'device supplementary panel is initially expanded');
unlike($view_source, qr/\bui_columns_start\(/,
	'device page has no additional standalone table');
is(scalar(@module_tables), 1, 'module page has one general information table');
is(scalar(@module_hidden), 1, 'module page has one supplementary panel');
like($module_source,
	qr/ui_hidden_table_start\([^;]*"module_additional"\s*,\s*1\s*,/s,
	'module supplementary panel is initially expanded');
unlike($view_source, qr/ui_print_header\([^;]*"intro"/s,
	'device page does not show module help');
unlike($module_source, qr/ui_print_header\([^;]*"intro"/s,
	'module page does not show module help');
like($view_source,
	qr/ui_print_header\([^;]*""\s*,\s*undef\s*,\s*0\s*,\s*1\s*\);/s,
	'device page disables module help and configuration actions');
like($module_source,
	qr/ui_print_header\([^;]*""\s*,\s*undef\s*,\s*0\s*,\s*1\s*\);/s,
	'module page disables module help and configuration actions');

done_testing();
