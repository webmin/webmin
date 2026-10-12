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
our (@fixture, %config, @options, @health, $missing, $provider_error);
sub foreign_check { return $_[0] eq 'fdisk'; }
sub foreign_require {}
sub list_megaraid_subdisks { return $missing ? () : ([2,0,[]], [7,0,[]]); }
sub list_3ware_controllers { return $missing ? () : ('c0'); }
sub list_3ware_subdisks { return (['u0','c0',['p0','p2']]); }
sub count_subdisks { return $missing ? 0 : 2; }
sub indexof { my ($x,@v)=@_; for (0..$#v) { return $_ if $v[$_] eq $x; } return -1; }
# Mock the disk provider called through Webmin's module namespace.
{ package fdisk; ## no critic (Modules::RequireFilenameMatchesPackage)
    sub list_disks_partitions {
        push(@main::options, [@_]);
        if ($main::provider_error) {
            ${$_[2]} = $main::provider_error;
            return ();
        }
        return @main::fixture;
    }
}
my $source = source($smart);
for my $name (qw(list_smart_disks_partitions list_smart_disks_partitions_fdisk list_configured_raid_disks configured_raid_disk_desc unique_smart_disks get_extra_args smart_disk_discovery_error)) {
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
    $missing=1;
    my $error;
    my @failed;
    eval { @failed = list_smart_disks_partitions(1, \$error); };
    is($@, '', 'missing controller does not throw');
    is_deeply(\@failed, [], 'missing controller returns no partial inventory');
    like($error, qr/Incomplete .* SMART discovery/, 'missing controller error is reported');
    $missing=0;
    my @full=list_smart_disks_partitions(); my @disk=list_smart_disks_partitions(1);
    is_deeply(\@disk, \@full, 'disk-only preserves controller expansion');
}
@fixture=({device=>'/dev/sda',type=>'scsi',model=>'ST9750420AS'});
for my $disk_only (0,1) {
    @d=list_smart_disks_partitions($disk_only);
    is(scalar @d,1,'embedded 9750 model remains one disk');
    is($d[0]->{device},'/dev/sda','embedded 9750 model retains device');
    ok(!defined($d[0]->{subtype}),'embedded 9750 model is not a RAID member');
}
{
    local $provider_error = 'Disk inventory changed during SMART discovery';
    local $config{raid_devices} = '/dev/sda sat+megaraid 9 1';
    my $error;
    my @failed = list_smart_disks_partitions(1, \$error);
    is_deeply(\@failed, [], 'provider failure does not return configured partial inventory');
    is($error, $provider_error, 'provider failure reason reaches the caller');
    my @warnings;
    local $SIG{__WARN__} = sub { push(@warnings, @_); };
    @failed = list_smart_disks_partitions(1);
    is_deeply(\@failed, [], 'caller without error reference receives no partial inventory');
    is(scalar @warnings, 1, 'provider failure warns once without an error reference');
    like($warnings[0], qr/Disk inventory changed/, 'warning retains provider failure reason');
}
{
    local @fixture = ();
    local $config{raid_devices} = '/dev/sda sat+megaraid 9 1';
    my $error = 'previous failure';
    my @configured = list_smart_disks_partitions(1, \$error);
    is(scalar @configured, 1, 'valid empty provider still includes configured RAID');
    is($error, undef, 'successful call clears stale error');
}
done_testing();
