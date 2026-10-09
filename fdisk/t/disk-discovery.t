use strict;
use warnings;
use Test::More;
use JSON::PP;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use IPC::Open3;
use Symbol qw(gensym);

my $here = abs_path(dirname(__FILE__));
my $library = "$here/../fdisk-lib.pl";
my $fixture;

sub write_file {
    my ($name, $value) = @_;
    make_path(dirname("$fixture/$name"));
    open(my $fh, '>', "$fixture/$name") or die $!;
    print {$fh} $value;
    close($fh) or die $!;
}
sub disk {
    my ($name, $vendor, $model) = @_;
    write_file("dev/$name", '');
    write_file("sys/block/$name/device/vendor", "$vendor\n");
    write_file("sys/block/$name/device/model", "$model\n");
    make_path("$fixture/sys/class/block/$name");
}
sub setup_fixture {
    $fixture = tempdir(CLEANUP => 1);
    write_file('proc/partitions', "major minor  #blocks  name\n 8 0 100 sda\n 8 1 90 sda1\n");
    write_file('proc/scsi/scsi', "Attached devices:\n");
    disk('sda', 'Example', 'USB NVMe');
    disk('sdb', 'ATA', 'second');
    make_path("$fixture/dev/disk/by-id");
    symlink('../../sda', "$fixture/dev/disk/by-id/old") or die $!;
    write_file('tool-output', '');
    for my $tool (qw(parted fdisk)) {
        write_file("bin/$tool", "#!$^X\n" . <<'TOOL');
use strict;
my $root = $ENV{'FIXTURE_ROOT'};
open(my $calls, '>>', "$root/calls") or die $!;
print {$calls} "query\n";
close($calls);
open(my $data, '<', "$root/tool-output") or die $!;
print while <$data>;
TOOL
        chmod(0755, "$fixture/bin/$tool") or die $!;
    }
}
sub run_library {
    my ($scenario) = @_;
    local $ENV{'PATH'} = "$fixture/bin:$ENV{'PATH'}";
    local $ENV{'FIXTURE_ROOT'} = $fixture;
    local $SIG{'ALRM'} = sub { die "fixture timed out\n"; };
    alarm(15);
    my $err = gensym();
    my $pid = open3(my $in, my $out, $err, $^X, "$here/fixtures/disk-discovery.pl",
                   $library, $fixture, $scenario || 'disk');
    close($in);
    my ($stdout, $stderr);
    { local $/; $stdout = <$out>; $stderr = <$err>; }
    waitpid($pid, 0);
    my $status = $?;
    alarm(0);
    is($status, 0, 'fixture process succeeds') or diag($stderr);
    is($stderr, '', 'no unexpected warnings');
    return decode_json($stdout);
}
sub parted_output {
    my ($table) = @_;
    my $part = $table eq 'gpt' ? ' 1 1cyl 9cyl 8cyl ext4 name' : ' 1 1cyl 9cyl 8cyl primary ext4';
    my $extra = $table eq 'msdos' ? " 2 9cyl 10cyl 1cyl extended\n" : '';
    write_file('tool-output', "Disk $fixture/dev/sda: 10cyl\nBIOS cylinder,head,sector geometry: 10,4,8. Each cylinder is 16384b.\nPartition Table: $table\n$part\n$extra");
}

subtest 'disk-only inventory avoids partition commands and cache' => sub {
    setup_fixture();
    my $r = run_library();
    is($r->{'error'}, undef, 'discovery succeeds');
    my $d = $r->{'results'}->[0]->[0];
    is($d->{'model'}, 'Example USB NVMe', 'model retained');
    is_deeply($d->{'ids'}, ['old'], 'stable ID retained');
    ok(!exists($d->{'parts'}) && !exists($d->{'table'}) && !exists($d->{'size'}),
       'metadata does not claim partition or geometry data');
    is_deeply($r->{'cache'}, [], 'full partition cache not populated');
    ok(!-e "$fixture/calls", 'no partition tool called');
};
subtest 'full discovery still parses GPT, MBR and extended partitions' => sub {
    for my $table (qw(gpt msdos)) {
        setup_fixture(); parted_output($table);
        my $r = run_library('full');
        is($r->{'error'}, undef, 'full discovery succeeds');
        my $d = $r->{'results'}->[0]->[0];
        is($d->{'table'}, $table, 'partition table retained');
        is(scalar(@{$d->{'parts'}}), $table eq 'gpt' ? 1 : 2, 'partitions retained');
        is($d->{'model'}, 'Example USB NVMe', 'shared model metadata retained');
        ok(-e "$fixture/calls", 'full path queries partition tool');
    }
};
subtest 'full fdisk fallback remains available' => sub {
    setup_fixture();
    write_file('tool-output', "Disk $fixture/dev/sda: 1 GiB, 1073741824 bytes, 2097152 sectors\nGeometry: 4 heads, 8 sectors/track, 10 cylinders\nUnits = cylinders of 32 * 512\nDisklabel type: gpt\n$fixture/dev/sda1 1 9 9 4K Linux filesystem\n");
    my $r = run_library('full_fdisk');
    is($r->{'error'}, undef, 'fdisk fallback succeeds');
    is(scalar(@{$r->{'results'}->[0]->[0]->{'parts'}}), 1, 'fdisk partition retained');
    ok(-e "$fixture/calls", 'fdisk command used');
};
subtest 'cache isolation in both call orders' => sub {
    for my $scenario (qw(disk_full full_disk)) {
        setup_fixture(); parted_output('gpt');
        my $r = run_library($scenario);
        my ($disk, $full) = @{$r->{'results'}};
        ($disk, $full) = ($full, $disk) if $scenario eq 'full_disk';
        ok(!exists($disk->[0]->{'parts'}), 'disk-only result has no partition claim');
        ok(@{$full->[0]->{'parts'}}, 'full result has partitions');
        is_deeply($r->{'cache'}, $full, 'full cache contains only full result');
    }
};
subtest 'replacement refreshes model and identifiers' => sub {
    setup_fixture(); my $r = run_library('refresh');
    my ($a, $b) = map { $_->[0] } @{$r->{'results'}};
    is($a->{'model'}, 'Example USB NVMe', 'first model');
    is($b->{'model'}, 'Example Replacement', 'new model');
    is_deeply($b->{'ids'}, ['new'], 'new stable ID');
};
subtest 'addition and removal refresh inventory' => sub {
    setup_fixture(); my $r = run_library('remove_add');
    is($r->{'results'}->[0]->[0]->{'device'}, "$fixture/dev/sda", 'initial disk');
    is($r->{'results'}->[1]->[0]->{'device'}, "$fixture/dev/sdb", 'replacement inventory');
};
subtest 'disappearance during scan fails explicitly' => sub {
    setup_fixture(); like(run_library('race')->{'error'}, qr/Missing device/, 'no stale result');
};
subtest 'missing model and missing inventory fail explicitly' => sub {
    setup_fixture();
    unlink("$fixture/sys/block/sda/device/vendor", "$fixture/sys/block/sda/device/model");
    like(run_library()->{'error'}, qr/Missing disk model/, 'missing model fails');
    unlink("$fixture/proc/partitions");
    like(run_library()->{'error'}, qr/Cannot read disk inventory/, 'missing inventory fails');
};
subtest 'multiple drives and namespaces retain classifications' => sub {
    setup_fixture();
    my @names = qw(sda sdaa nvme0n1 nvme0n2 mmcblk0 xvda vda hda);
    write_file('proc/partitions', "major minor  #blocks  name\n" . join('', map { "8 0 100 $_\n" } @names));
    write_file('proc/ide/hda/media', "disk\n"); write_file('proc/ide/hda/model', "IDE fixture\n");
    disk($_, 'Example', 'disk') for @names;
    my $r = run_library();
    is($r->{'error'}, undef, 'multi-drive discovery succeeds');
    is_deeply([sort map { $_->{'short'} } @{$r->{'results'}->[0]}], [sort @names], 'all devices retained');
    my ($virtio) = grep { $_->{'short'} eq 'vda' } @{$r->{'results'}->[0]};
    is($virtio->{'type'}, 'virtio', 'VirtIO classification preserved');
    ok(!-e "$fixture/calls", 'multiple drives need no partition query');
};
subtest 'unpartitioned disk without stable link remains discoverable' => sub {
    setup_fixture(); unlink("$fixture/dev/disk/by-id/old");
    write_file('proc/partitions', "major minor  #blocks  name\n 8 0 100 sda\n");
    my $r = run_library();
    is(scalar(@{$r->{'results'}->[0]}), 1, 'disk retained');
    is($r->{'results'}->[0]->[0]->{'ids'}, undef, 'no fabricated identifiers');
};
subtest 'legacy controller metadata and SCSI fallback remain available' => sub {
    setup_fixture();
    my @names = qw(cciss/c0d0 rd/c0d0 ida/c0d0);
    write_file('proc/partitions', "major minor  #blocks  name\n" . join('', map { "8 0 100 $_\n" } @names));
    write_file("dev/$_", '') for @names;
    write_file('proc/driver/cciss/cciss0', "cciss0: Smart Array\n");
    write_file('proc/rd/c0/current_status', "Configuring Mylex\n");
    write_file('proc/driver/cpqarray/ida0', "ida0: Compaq\n");
    my $r = run_library();
    is_deeply([map { $_->{'model'} } @{$r->{'results'}->[0]}], ['Smart Array','Mylex','Compaq'], 'controller models retained');
    ok(!grep({ $_->{'type'} ne 'raid' } @{$r->{'results'}->[0]}), 'legacy RAID classification retained');
    write_file('proc/partitions', "major minor  #blocks  name\n 8 0 100 sda\n");
    remove_tree("$fixture/sys/block/sda/device");
    write_file('proc/scsi/scsi', "Attached devices:\nHost: scsi0 Channel: 00 Id: 00 Lun: 00\n  Vendor: LSI Model: RAID fixture Rev: 1\n  Type: Direct-Access\n");
    like(run_library()->{'results'}->[0]->[0]->{'model'}, qr/LSI/, 'proc SCSI fallback retained');
};
done_testing();
