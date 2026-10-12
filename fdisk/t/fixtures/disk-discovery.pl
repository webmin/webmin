use strict;
use warnings;
use JSON::PP;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
my ($source, $root, $scenario) = @ARGV;
open(my $fh, '<', $source) or die $!;
local $/; my $code = <$fh>; close($fh); $/ = "\n";
# Keep the actual library functions; replace literal filesystem roots only.
$code = substr($code, index($code, 'sub list_disks_partitions'));
for my $prefix ('/proc/', '/sys/', '/dev/') {
    $code =~ s/\Q$prefix\E/$root$prefix/g;
}
our (@reads, $has_parted, @list_disks_partitions_cache, $change);
$has_parted = $scenario !~ /fdisk/;
# Mock the cross-module filesystem helper used by the real library.
{ package mount; ## no critic (Modules::RequireFilenameMatchesPackage)
    sub list_fstypes { return ('ext2', 'ext3', 'ext4', 'xfs'); }
}
sub text { return join(' ', @_); }
sub indexof { my ($x, @v) = @_; for (0..$#v) { return $_ if $v[$_] eq $x; } return -1; }
sub resolve_links { return abs_path($_[0]); }
sub simplify_path { my $p = $_[0]; $p =~ s{/dev/disk/by-id/../../}{/dev/}; return $p; }
sub read_file_contents {
    my ($p) = @_;
    die "Attempt to read device data" if $p =~ m{\Q$root\E/dev/};
    push(@reads, $p);
    open(my $f, '<', $p) or return '';
    local $/; my $s = <$f>; close($f);
    if ($change && $p =~ m{/device/model$}) {
        unlink("$root/dev/sda");
        $change = 0;
    }
    return $s;
}
{
    # Load the real legacy functions, which use Webmin package globals.
    no strict 'vars'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
    # Webmin does not enable these warnings for optional legacy metadata.
    no warnings 'uninitialized';
    eval $code; ## no critic (BuiltinFunctions::ProhibitStringyEval)
    die $@ if $@;
}
my @results;
my $error;
my $exception;
my @warnings;
eval {
    if ($scenario eq 'race') { $change = 1; }
    if ($scenario eq 'reset_error') { $error = 'previous failure'; }
    if ($scenario eq 'disk_full' || $scenario eq 'full_disk') {
        my $first = $scenario eq 'disk_full' ? 1 : 0;
        push(@results, [list_disks_partitions(undef, $first, \$error)]);
        push(@results, [list_disks_partitions(undef, !$first, \$error)]);
    }
    elsif ($scenario eq 'refresh') {
        push(@results, [list_disks_partitions(undef, 1, \$error)]);
        open(my $f, '>', "$root/sys/block/sda/device/model") or die $!;
        print $f "Replacement\n"; close($f);
        unlink("$root/dev/disk/by-id/old");
        symlink('../../sda', "$root/dev/disk/by-id/new") or die $!;
        push(@results, [list_disks_partitions(undef, 1, \$error)]);
    }
    elsif ($scenario eq 'remove_add') {
        push(@results, [list_disks_partitions(undef, 1, \$error)]);
        open(my $f, '>', "$root/proc/partitions") or die $!;
        print $f "major minor  #blocks  name\n 8 16 100 sdb\n"; close($f);
        push(@results, [list_disks_partitions(undef, 1, \$error)]);
    }
    elsif ($scenario eq 'warn') {
        local $SIG{__WARN__} = sub { push(@warnings, @_); };
        push(@results, [list_disks_partitions(undef, 1)]);
    }
    else { push(@results, [list_disks_partitions(undef, $scenario =~ /^full/ ? 0 : 1, \$error)]); }
    1;
} or $exception = $@;
print JSON::PP->new->canonical->encode({results=>\@results, error=>$error, exception=>$exception, warnings=>\@warnings, reads=>\@reads, cache=>\@list_disks_partitions_cache});
