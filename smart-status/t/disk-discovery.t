use strict;
use warnings;
use Test::More;
use JSON::PP;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
my $root = abs_path(dirname(__FILE__).'/../..');
my $smart = "$root/smart-status/smart-status-lib.pl";
my $system = "$root/system-status/system-status-lib.pl";
# Synthetic disk metadata and controller helpers; never invoke SMART or disks.
sub source {
    open(my $fh, '<', $_[0]) or die $!;
    local $/; return <$fh>;
}
sub extract {
    my ($source, $name) = @_;
    $source =~ /^(sub \Q$name\E\n\{.*?^\})/ms or die "Missing function $name";
    return $1;
}
our (@fixture, %config, @options, @health, $missing);
sub foreign_check { return $_[0] eq 'fdisk'; }
sub foreign_require {}
sub list_megaraid_subdisks { return $missing ? () : ([2,0,[]], [7,0,[]]); }
sub list_3ware_controllers { return $missing ? () : ('c0'); }
sub list_3ware_subdisks { return (['u0','c0',['p0','p2']]); }
sub count_subdisks { return $missing ? 0 : 2; }
sub indexof { my ($x,@v)=@_; for (0..$#v) { return $_ if $v[$_] eq $x; } return -1; }
# Mock the disk provider called through Webmin's module namespace.
{ package fdisk; ## no critic (Modules::RequireFilenameMatchesPackage)
    sub list_disks_partitions { push(@main::options, [@_]); return @main::fixture; }
}
my $source = source($smart);
for my $name (qw(list_smart_disks_partitions list_smart_disks_partitions_fdisk list_configured_raid_disks configured_raid_disk_desc unique_smart_disks get_extra_args)) {
    # Load the real legacy functions, which use Webmin package globals.
    no strict 'vars'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
    eval extract($source, $name); ## no critic (BuiltinFunctions::ProhibitStringyEval)
    die $@ if $@;
}
@fixture=({device=>'/dev/sda',type=>'scsi',model=>'Example USB',ids=>['fixture-usb']},
 {device=>'/dev/sdaa',type=>'scsi',model=>'Example SATA'},
 {device=>'/dev/nvme0n1',type=>'scsi',model=>'Example NVMe'},
 {device=>'/dev/mmcblk0',type=>'ide'}, {device=>'/dev/vda',type=>'virtio'});
my @d=list_smart_disks_partitions();
is_deeply([map {$_->{device}} @d], ['/dev/mmcblk0','/dev/nvme0n1','/dev/sda','/dev/sdaa'], 'baseline multi-drive inclusion and ordering');
is_deeply((grep {$_->{device} eq '/dev/sda'} @d)[0]->{ids}, ['fixture-usb'], 'stable identifiers carried through');
@fixture=({device=>'/dev/sda',type=>'scsi',model=>'LSI Controller'});
@d=list_smart_disks_partitions();
is_deeply([map {[$_->{subtype},$_->{subdisk}]} @d], [['sat+megaraid',2],['sat+megaraid',7]], 'LSI model selects physical members');
$config{extra}='-T permissive';is(get_extra_args($d[0]->{device},$d[0]), '-T permissive -d sat+megaraid,2', 'passthrough arguments preserved');
$config{raid_devices}='/dev/sda sat+megaraid 2 1';
@d=list_smart_disks_partitions();is(scalar @d,2,'manual duplicate removed by full passthrough identity');
$config{raid_devices}='/dev/sda sat+megaraid 9 1';
@d=list_smart_disks_partitions();is_deeply([map {$_->{subdisk}} @d],[2,7,9],'additional configured RAID member retained');
$config{raid_devices}='';@fixture=({device=>'/dev/cciss/c0d0',type=>'raid',model=>'Smart Array'});
@d=list_smart_disks_partitions();is_deeply([map {[$_->{subtype},$_->{subdisk}]} @d],[['cciss',0],['cciss',1]],'cciss branch retained');
@fixture=({device=>'/dev/sda',type=>'scsi',model=>'AMCC 9750'});
@d=list_smart_disks_partitions();is_deeply([map {[$_->{subtype},$_->{subdisk}]} @d],[['3ware','0'],['3ware','2']],'3ware model branch retained');
@fixture=({device=>'/dev/sdb',type=>'scsi',model=>'new drive'});
@d=list_smart_disks_partitions();is_deeply([map {$_->{device}} @d],['/dev/sdb'],'wrapper accepts changed provider inventory without caching');


@options=(); list_smart_disks_partitions(1);
ok($options[0]->[1], 'disk-only request reaches fdisk provider');
@options=(); list_smart_disks_partitions();
ok(!$options[0]->[1], 'default retains full provider');
for my $case (['LSI', '/dev/sda'], ['AMCC 9750','/dev/sda'], ['Smart Array','/dev/cciss/c0d0']) {
    @fixture=({device=>$case->[1],type=>'scsi',model=>$case->[0]});
    $missing=1; eval { list_smart_disks_partitions(1); };
    like($@, qr/Incomplete .* SMART discovery/, 'missing controller members fail explicitly');
    $missing=0;
    my @full=list_smart_disks_partitions(); my @disk=list_smart_disks_partitions(1);
    is_deeply(\@disk, \@full, 'disk-only preserves controller expansion');
}
{ package smart_status;
    sub list_smart_disks_partitions { return main::list_smart_disks_partitions(@_); }
    sub get_drive_status {
        my ($dev,$disk,$basic)=@_;
        push(@main::health, {device=>$dev, subtype=>$disk->{subtype},subdisk=>$disk->{subdisk},basic=>$basic});
        return {attribs=>[['Temperature Celsius',32]],check=>1,errors=>undef};
    }
}
{ package system_status;
    our %config;
    sub foreign_require {}
    sub foreign_installed { return 1; }
    sub foreign_check { return $_[0] eq 'proc' || $_[0] eq 'mount'; }
}
{ package proc;
    sub get_cpu_info { return (0.1, 0.2, 0.3); }
    sub list_processes { return ({pid=>1}); }
    sub get_kernel_info { return ('fixture-version', 'fixture-arch', 'Linux'); }
}
{ package mount;
    sub local_disk_space { return (100, 40, [], 60); }
}
my $poll=extract(source($system), 'get_current_drive_temps').
         extract(source($system), 'collect_system_info');
{
    # Evaluate the scheduled caller in its actual Webmin namespace.
    no strict 'vars'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
    eval 'package system_status; our %config; '.$poll; ## no critic (BuiltinFunctions::ProhibitStringyEval)
    die $@ if $@;
}
@fixture=({device=>'/dev/sda',type=>'scsi',model=>'LSI Controller'});
@options=();@health=();my @temps=system_status::get_current_drive_temps();
ok($options[0]->[1], 'scheduled caller selects disk-only discovery');
is(scalar @temps,2,'scheduled collection covers each RAID member');
is_deeply([map {[$_->{subtype},$_->{subdisk},$_->{basic}]} @health], [['sat+megaraid',2,1],['sat+megaraid',7,1]], 'scheduled health retains passthrough and basic query flag');
{
    local $missing = 1;
    local @fixture = ({device=>'/dev/sda',type=>'scsi',model=>'ordinary drive'},
                     {device=>'/dev/sdb',type=>'scsi',model=>'LSI Controller'});
    local @health = ();
    my @warnings;
    local $SIG{__WARN__} = sub { push(@warnings, @_); };
    my @failed_temps = system_status::get_current_drive_temps();
    is_deeply(\@failed_temps, [], 'discovery failure returns no partial temperatures');
    is(scalar @health, 0, 'failed discovery never queries SMART');
    is(scalar @warnings, 1, 'discovery failure is reported once');
    like($warnings[0], qr/SMART disk discovery failed: Incomplete MegaRAID SMART discovery/,
         'reported failure retains the discovery reason');
    @warnings = ();
    my $info = system_status::collect_system_info();
    is_deeply($info->{'load'}, [0.1,0.2,0.3], 'CPU collection survives discovery failure');
    is($info->{'disk_used'}, 60, 'disk-space collection survives discovery failure');
    ok(!exists($info->{'drivetemps'}), 'failed collection makes no temperature claim');
    is(scalar @health, 0, 'system collection does not query a partial disk inventory');
    is(scalar @warnings, 1, 'system collection reports its discovery failure');
}
$system_status::config{collect_notemp}=1;@options=();
is(scalar(system_status::get_current_drive_temps()),0,'existing temperature override respected');
is(scalar @options,0,'disabled collection does not discover disks');

@fixture=({device=>'/dev/sda',type=>'scsi',model=>'ST9750420AS'});
for my $disk_only (0,1) {
    @d=list_smart_disks_partitions($disk_only);
    is(scalar @d,1,'embedded 9750 model remains one disk');
    is($d[0]->{device},'/dev/sda','embedded 9750 model retains device');
    ok(!defined($d[0]->{subtype}),'embedded 9750 model is not a RAID member');
}
done_testing();
