use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

my $library = abs_path(dirname(__FILE__).'/../system-status-lib.pl');
open(my $fh, '<', $library) or die $!;
my $source;
{ local $/; $source = <$fh>; }
close($fh) or die $!;
sub extract {
    my ($name) = @_;
    $source =~ /^(sub \Q$name\E\n\{.*?^\})/ms or die "Missing function $name";
    return $1;
}

our (@options, @health, @fixture, $discovery_error);
# Mock the SMART provider; never run smartctl or query a real disk.
{ package smart_status; ## no critic (Modules::RequireFilenameMatchesPackage)
    sub list_smart_disks_partitions {
        push(@main::options, [@_]);
        if ($main::discovery_error) {
            ${$_[1]} = $main::discovery_error;
            return ();
        }
        ${$_[1]} = undef;
        return @main::fixture;
    }
    sub get_drive_status {
        my ($dev, $disk, $basic) = @_;
        push(@main::health, {device=>$dev, subtype=>$disk->{subtype},
                           subdisk=>$disk->{subdisk}, basic=>$basic});
        return {attribs=>[['Temperature Celsius',32]], check=>1, errors=>undef};
    }
}
{ package system_status;
    our (%config, %gconfig);
    sub foreign_require {}
    sub foreign_installed { return $_[0] eq 'smart-status'; }
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

# Test the actual collector functions in their Webmin namespace.
my $code = 'package system_status; our (%config, %gconfig); '.
           extract('get_current_drive_temps').extract('collect_system_info');
eval $code; ## no critic (BuiltinFunctions::ProhibitStringyEval)
die $@ if $@;
@fixture = ({device=>'/dev/sda', subtype=>'sat+megaraid', subdisk=>2},
            {device=>'/dev/sda', subtype=>'sat+megaraid', subdisk=>7});
my @temps = system_status::get_current_drive_temps();
ok($options[0]->[0], 'scheduled caller requests disk-only discovery');
is(ref($options[0]->[1]), 'SCALAR', 'collector requests an explicit error result');
is(scalar @temps, 2, 'every discovered RAID member is collected');
is_deeply([map {[$_->{subtype},$_->{subdisk},$_->{basic}]} @health],
          [['sat+megaraid',2,1],['sat+megaraid',7,1]],
          'SMART passthrough and basic query flag are retained');
{
    local $discovery_error = 'Incomplete MegaRAID SMART discovery';
    local @health = ();
    my @warnings;
    local $SIG{__WARN__} = sub { push(@warnings, @_); };
    my @failed_temps = system_status::get_current_drive_temps();
    is_deeply(\@failed_temps, [], 'discovery failure returns no temperatures');
    is(scalar @health, 0, 'failed discovery never queries SMART');
    is(scalar @warnings, 1, 'failure is reported once');
    like($warnings[0], qr/SMART disk discovery failed: Incomplete MegaRAID/,
         'reported failure retains the reason');
    @warnings = ();
    my $info = system_status::collect_system_info();
    is_deeply($info->{'load'}, [0.1,0.2,0.3], 'CPU collection survives discovery failure');
    is($info->{'disk_used'}, 60, 'disk-space collection survives discovery failure');
    ok(!exists($info->{'drivetemps'}), 'failed collection makes no temperature claim');
    is(scalar @health, 0, 'system collection never queries partial inventory');
    is(scalar @warnings, 1, 'system collection reports its discovery failure');
}
@options = (); @health = ();
local @fixture = ();
my @warnings;
{ local $SIG{__WARN__} = sub { push(@warnings, @_); };
    is(scalar(system_status::get_current_drive_temps()), 0, 'empty inventory is supported');
}
is(scalar @warnings, 0, 'valid empty inventory is not an error');
$system_status::config{collect_notemp} = 1; @options = ();
is(scalar(system_status::get_current_drive_temps()), 0, 'temperature override is respected');
is(scalar @options, 0, 'disabled collection does not discover disks');
done_testing();
