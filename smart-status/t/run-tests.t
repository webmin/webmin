#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use JSON::PP;

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
my $tmp = tempdir(CLEANUP => 1);
require "$root/t/test-lib.pl";
unshift(@INC, $root);
require WebminCore;

# Load the real libraries without reading the installed Webmin configuration.
{
	no warnings 'redefine';
	local *WebminCore::init_config = sub { };
	{
		package smart_status;
		require "$root/smart-status/smart-status-lib.pl";
	}
	{
		package system_status;
		our $module_config_directory = $tmp;
		our $module_var_directory = $tmp;
		require "$root/system-status/system-status-lib.pl";
	}
}

# Exercise both command execution paths using a fake smartctl, never a disk.
write_text("$tmp/smartctl.pl", <<'EOF');
use strict;
use warnings;
use JSON::PP;
my $dir = shift(@ARGV);
open(my $log, '>>', "$dir/commands") or die $!;
print {$log} encode_json(\@ARGV)."\n";
close($log);
open(my $fh, '<', "$dir/response") or die $!;
my $response = do { local $/; decode_json(<$fh>) };
my $device = $ARGV[-1];
my $data = $response->{$device} || {};
my %flags = map { $_ => 1 } @ARGV;
if ($flags{'--version'}) {
	print "smartctl 7.4 [test]\nsmartmontools release 7.4\n";
}
if ($flags{'-i'} || $flags{'-a'}) {
	print $data->{'info'} || "SMART support is: Unavailable\n";
}
if ($flags{'-H'} || $flags{'-c'} || $flags{'-a'}) {
	print $data->{'health'} || "";
}
if ($flags{'-A'} || $flags{'-vl'} || $flags{'-a'}) {
	print $data->{'attributes'} || "";
}
if ($flags{'error'} || $flags{'-vl'} || $flags{'-a'}) {
	print "ATA Error Count: 12\n";
}
if ($flags{'-a'}) {
	print "SMART Self-test log structure revision number 1\n";
}
exit($data->{'exit'} || 0);
EOF

$smart_status::config{'smartctl'} =
	quotemeta($^X)." ".quotemeta("$tmp/smartctl.pl")." ".quotemeta($tmp);
$smart_status::config{'attribs'} = 1;
$smart_status::config{'ata'} = 0;
$smart_status::config{'extra'} = '';

my $ata = {
	'info' => "Device Model: Test ATA\nSMART support is: Available\n".
		  "SMART support is: Enabled\n",
	'health' => "SMART overall-health self-assessment test result: PASSED\n",
	'attributes' => "194 Temperature_Celsius 0x0022 100 100 000 Old_age Always - 37 (Min/Max 20/45)\n",
};
my $scsi = {
	'info' => "Device supports SMART and is Enabled\n",
	'health' => "SMART Health Status: OK\n",
	'attributes' => "Current Drive Temperature: 38 C\n",
};
my $nvme = {
	'info' => "Model Number: Test NVMe\nNVMe Version: 1.4\n",
	'health' => "SMART overall-health self-assessment test result: PASSED\n",
	'attributes' => "Temperature: 39 Celsius\n",
};
my $legacy = {
	'health' => "Device supports S.M.A.R.T. and is enabled\n".
		    "Check S.M.A.R.T. Passed\n",
	'attributes' => "(194)Temperature             0x0022 100 100 0 36\n",
};

# set_responses(&responses)
# Supplies device output and starts a fresh command trace for each case.
sub set_responses
{
write_text("$tmp/response", encode_json($_[0]));
write_text("$tmp/commands", "");
}

# commands()
# Returns the arguments received by each fake smartctl process.
sub commands
{
return map { decode_json($_) } split(/\n/, read_text("$tmp/commands"));
}

# collect_temps(&drives)
# Runs the real collector and parser with only disk discovery stubbed out.
sub collect_temps
{
my ($drives) = @_;
no warnings 'redefine';
local *system_status::foreign_installed = sub { return 1; };
local *system_status::foreign_require = sub { };
local *smart_status::list_smart_disks_partitions = sub { return @$drives; };
return [ system_status::get_current_drive_temps() ];
}

# The collector must retain ATA, SCSI and USB NVMe temperatures without -a.
set_responses({ '/dev/sda' => $ata, '/dev/sdb' => $scsi, '/dev/sdc' => $nvme });
my $temps = collect_temps([ map { { 'device' => $_ } }
			   qw(/dev/sda /dev/sdb /dev/sdc) ]);
is_deeply([ map { [ $_->{'device'}, $_->{'temp'}, $_->{'failed'} ] } @$temps ],
	  [ [ '/dev/sda', 37, '' ], [ '/dev/sdb', 38, '' ], [ '/dev/sdc', 39, '' ] ],
	  'collector preserves temperature and health across drive protocols');
my @commands = commands();
is(scalar(grep { grep { $_ eq '-A' } @$_ } @commands), 3,
   'each drive is queried for attributes');
is(scalar(grep { grep { $_ eq 'error' } @$_ } @commands), 3,
   'each drive still requests its error log');
ok(!grep({ grep { /^(?:-a|-x|selftest|selective)$/ } @$_ } @commands),
   'temperature polling never requests all details or self-test logs');

# Full SMART details remain available through the default API.
set_responses({ '/dev/sda' => $ata });
my $status = smart_status::get_drive_status('/dev/sda', { 'device' => '/dev/sda' });
like($status->{'raw'}, qr/SMART Self-test log/,
     'default drive status retains self-test logs');
like($status->{'raw'}, qr/Device Model: Test ATA/,
     'default drive status retains identification details');
my $basic = smart_status::get_drive_status('/dev/sda', { 'device' => '/dev/sda' }, 1);
like($basic->{'raw'}, qr/ATA Error Count: 12/,
     'basic status retains error log output');

# Basic mode must survive both successful controller probes and fallback.
foreach my $controller_ok (0, 1) {
	set_responses({ '/dev/nvme0' => $controller_ok ? $nvme : {},
			'/dev/nvme0n1' => $nvme });
	$temps = collect_temps([ { 'device' => '/dev/nvme0n1' } ]);
	is($temps->[0]->{'temp'}, 39,
	   "NVMe temperature is collected with controller support $controller_ok");
	@commands = commands();
	is($commands[0]->[-1], '/dev/nvme0', 'controller is tried first');
	is($commands[-1]->[-1], $controller_ok ? '/dev/nvme0' : '/dev/nvme0n1',
	   'attributes use the supported NVMe device');
	ok(!grep({ grep { $_ eq '-a' } @$_ } @commands),
	   'NVMe recursion retains basic mode');
}

# Keep administrator-supplied options and hardware RAID addressing.
{
	local $smart_status::config{'extra'} = '-q noserial';
	local $smart_status::config{'ata'} = 1;
	set_responses({ '/dev/sda' => $ata });
	$temps = collect_temps([ { 'device' => '/dev/sda',
				  'subtype' => 'sat+megaraid', 'subdisk' => 2 } ]);
	is($temps->[0]->{'temp'}, 37, 'RAID drive temperature is collected');
	@commands = commands();
	is_deeply($commands[-1],
		  [ '-q', 'noserial', '-d', 'sat+megaraid,2', '-A', '-l', 'error', '/dev/sda' ],
		  'extra options and RAID selection are preserved over forced ATA');
	set_responses({ '/dev/sda' => $ata });
	collect_temps([ { 'device' => '/dev/sda' } ]);
	@commands = commands();
	is_deeply($commands[-1],
		  [ '-q', 'noserial', '-d', 'ata', '-A', '-l', 'error', '/dev/sda' ],
		  'forced ATA remains available without a RAID subdisk');
}

# Smartctl 5.0 uses combined single-letter options for attributes and errors.
{
	local $smart_status::smartctl_version_cache = 5.0;
	set_responses({ '/dev/hda' => $legacy });
	$status = smart_status::get_drive_status('/dev/hda', { 'device' => '/dev/hda' }, 1);
	is($status->{'attribs'}->[0]->[1], 36, 'legacy attribute values are preserved');
	@commands = commands();
	is_deeply($commands[-1], [ '-vl', '/dev/hda' ],
		  'legacy polling omits the self-test log with compatible flags');
}

# Preserve failing health reports, even when smartctl returns a failure bit.
set_responses({ '/dev/sda' => { %$ata, 'exit' => 8,
	'health' => "SMART overall-health self-assessment test result: FAILED!\n" } });
$temps = collect_temps([ { 'device' => '/dev/sda' } ]);
is($temps->[0]->{'failed'}, 1, 'collector retains failed SMART health');
is($temps->[0]->{'temp'}, 37, 'nonzero SMART status does not discard temperature');

# Unsupported drives and existing collection settings must still be respected.
set_responses({ '/dev/sda' => {} });
is_deeply(collect_temps([ { 'device' => '/dev/sda' } ]), [],
	  'unsupported drives have no temperature');
is(scalar(commands()), 1, 'unsupported drives stop after the support query');
{
	local $smart_status::config{'attribs'} = 0;
	set_responses({ '/dev/sda' => $ata });
	is_deeply(collect_temps([ { 'device' => '/dev/sda' } ]), [],
		  'disabled attributes retain their existing behavior');
	@commands = commands();
	is(scalar(@commands), 2, 'disabled attributes only query support and health');
}
{
	local $system_status::config{'collect_notemp'} = 1;
	set_responses({ '/dev/sda' => $ata });
	is_deeply(collect_temps([ { 'device' => '/dev/sda' } ]), [],
		  'collect_notemp still disables temperature collection');
	is(scalar(commands()), 0, 'disabled collection does not invoke smartctl');
}

done_testing();
