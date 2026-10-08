#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Storable qw(dclone);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
unshift(@INC, "$root/mount");

# Load the real helpers and presenters without a Webmin installation or
# mounted test devices. Only discovery, access and HTML primitives are mocked.
BEGIN { $INC{'WebminCore.pm'} = 1; }
sub WebminCore::import { }
sub mount::init_config { }
sub mount::get_module_acl { return (); }
{
package mount;
do "$root/mount/mount-lib.pl" or die "mount-lib.pl: $@ $!";
}
$INC{'./mount-lib.pl'} = 1;
{
package mount;
do "$root/mount/config_info.pl" or die "config_info.pl: $@ $!";
}

my $filesystems = [
 { dir => '/', type => 'ext4', device => '/dev/test-root',
   total => 1000, free => 400, used => 550, itotal => 100, ifree => 40 },
 { dir => '/mnt/iso', type => 'udf', device => '/dev/loop-test',
   total => 200, free => 0, used => 200, itotal => 100, ifree => 0 },
 { dir => '/mnt/iso-backup', type => 'ext4', device => '/dev/test-backup',
   total => 300, free => 100, used => 180 },
 { dir => '/mnt/iso/debian', type => 'iso9660', device => '/dev/loop-test2',
   total => 100, free => 0, used => 100, itotal => 100, ifree => 0 },
 { dir => '/mnt/a path,with comma', type => 'xfs', device => '/dev/test-data',
   total => 500, free => 200 },
];
my $original = dclone($filesystems);
sub visible_paths
{
return [ map { $_->{'dir'} } @{mount::filter_dashboard_filesystems($filesystems)} ];
}
my @paths = map { $_->{'dir'} } @$filesystems;
%mount::config = ();
is_deeply(visible_paths(), \@paths, 'empty configuration preserves every filesystem');
is_deeply([ mount::filter_dashboard_disk_space(2100, 700, $filesystems, undef) ],
          [ 2100, 700, $filesystems, undef ], 'unchanged list preserves raw aggregate semantics');

$mount::config{'sysinfo_exclude_types'} = ' UDF, udf, , ISO9660 ';
is_deeply(visible_paths(), [ @paths[0,2,4] ], 'types normalize case, whitespace and duplicates');
$mount::config{'sysinfo_exclude_types'} = 'ud';
is_deeply(visible_paths(), \@paths, 'type matching is exact');
%mount::config = (sysinfo_exclude_mounts => " /mnt/iso/// \t/mnt/a path,with comma\n");
is_deeply(visible_paths(), [ @paths[0,2,3] ], 'exact paths preserve spaces and commas, trim trailing slash');
$mount::config{'sysinfo_exclude_mounts'} = '/';
is_deeply(visible_paths(), [ @paths[1..4] ], 'root path remains matchable');
$mount::config{'sysinfo_exclude_mounts'} = '/mnt/ISO';
is_deeply(visible_paths(), \@paths, 'mount path matching is case sensitive');
%mount::config = (sysinfo_exclude_mount_regex => '^/mnt/iso(?:/|$)');
is_deeply(visible_paths(), [ @paths[0,2,4] ], 'regex excludes children but not similarly named siblings');
$mount::config{'sysinfo_exclude_mount_regex'} = '[';
is_deeply(visible_paths(), \@paths, 'invalid stored regex is ignored safely');
$mount::config{'sysinfo_exclude_mount_regex'} = '(?{ die "executed" })';
is_deeply(visible_paths(), \@paths, 'regex cannot execute embedded Perl code');
%mount::config = (sysinfo_exclude_types => 'udf',
                 sysinfo_exclude_mounts => '/mnt/iso-backup',
                 sysinfo_exclude_mount_regex => 'debian$');
is_deeply(visible_paths(), [ @paths[0,4] ], 'combined rules use logical OR');
is_deeply([ mount::filter_dashboard_disk_space(2100, 700, $filesystems, 1330) ],
          [ 1500, 600, [ @$filesystems[0,4] ], 850 ],
          'filtered totals use bytes, reported used values and fallback for missing used');
$mount::config{'sysinfo_exclude_mount_regex'} = '.*';
is_deeply([ mount::filter_dashboard_disk_space(2100, 700, $filesystems, 1330) ],
          [ 0, 0, [], 0 ], 'excluding every filesystem produces empty list and zero totals');
is_deeply($filesystems, $original, 'filtering never changes input hashes');

# Exercise the actual config.info parser, including multiline storage and
# rejection before config is written, rather than calling validators alone.
sub mount::error { die $_[0]; }
$mount::text{'config_edashboard_mount_regex'} = 'Invalid Dashboard regex';
sub read_file
{
my ($file, $hash, $order) = @_;
open(my $fh, '<', $file) or return 0;
while (<$fh>) {
 chomp;
 if (/^([^=#]+)=(.*)$/) { $hash->{$1} = $2; push(@$order, $1) if ($order); }
 }
return 1;
}
sub foreign_require { }
sub foreign_exists { return 0; }
sub unique { my %seen; return grep { !$seen{$_}++ } @_; }
sub foreign_call
{
my ($module, $fn, @args) = @_;
no strict 'refs';
local %mount::in = %main::in;
return &{"${module}::$fn"}(@args);
}
do "$root/config-lib.pl" or die "config-lib.pl: $@ $!";
our %in = (sysinfo_exclude_types => 'udf',
           sysinfo_exclude_mounts => "/mnt/iso\r\n/mnt/a path,with comma",
           sysinfo_exclude_mount_regex => '^/mnt/iso(?:/|$)');
my %saved;
parse_config(\%saved, "$root/mount/config.info", 'mount');
is($saved{'sysinfo_exclude_mounts'}, "/mnt/iso\t/mnt/a path,with comma",
   'standard multiline widget saves paths with tab separators');
is($saved{'sysinfo_exclude_mount_regex'}, $in{'sysinfo_exclude_mount_regex'},
   'configuration parser persists a validated regex');
$in{'sysinfo_exclude_mount_regex'} = '[';
eval { parse_config(\%saved, "$root/mount/config.info", 'mount'); };
like($@, qr/Invalid Dashboard regex/, 'configuration parser rejects invalid regex');
$in{'sysinfo_exclude_mount_regex'} = '';
eval { parse_config(\%saved, "$root/mount/config.info", 'mount'); };
is($@, '', 'empty regex can be saved');

# The cached raw record is deliberately shared between successive renders.
my $cached = { disk_total => 2100, disk_free => 700, disk_used => 1330,
               disk_fs => $filesystems };
my $cache_original = dclone($cached);
$INC{'system-status-lib.pl'} = 1;
sub status::get_collected_info { return $cached; }
sub status::foreign_require { }
sub status::foreign_available { return 0; }
sub status::get_module_acl { return (show => 'disk'); }
sub status::indexof { my ($v, @a) = @_; for (0..$#a) { return $_ if $a[$_] eq $v; } return -1; }
sub status::nice_size { return $_[0]; }
sub status::text { return join(' ', @_); }
{
package status;
do "$root/system-status/system_info.pl" or die "system_info.pl: $@ $!";
}
$status::text{'right_disk'} = 'Local disk space';
%mount::config = ();
my @unfiltered = status::list_system_info();
is(scalar(grep { $_->{'type'} eq 'warning' } @unfiltered), 2,
   'UDF emits block and inode warnings, ISO9660 retains existing suppression');
%mount::config = (sysinfo_exclude_types => 'udf');
my @filtered = status::list_system_info();
is(scalar(grep { $_->{'type'} eq 'warning' } @filtered), 0,
   'config change immediately removes block and inode warnings from cached data');
is_deeply($filtered[0]->{'table'}->[0]->{'chart'}, [1900, 1130],
          'aggregate chart is recalculated from cached visible filesystems');
is_deeply($filtered[0]->{'raw'}->[0]->{'disk_fs'}, [ @$filesystems[0,2,3,4] ],
          'Dashboard raw presentation data is also filtered');
is_deeply($cached, $cache_original, 'presentation does not mutate cached record');
%mount::config = ();
my @restored = status::list_system_info();
is_deeply(\@restored, \@unfiltered, 'removing exclusions restores cached data without recollection');

# Non-excluded writable filesystems must still report both space and inode
# exhaustion, including the nearly-full thresholds.
foreach my $remaining (0, 1) {
 my $full = { dir => '/data', type => 'ext4', total => 1000,
              free => $remaining, itotal => 1000, ifree => $remaining };
 local $cached->{'disk_fs'} = [ $full, $filesystems->[1] ];
 local %mount::config = (sysinfo_exclude_types => 'udf');
 my @warnings = grep { $_->{'type'} eq 'warning' } status::list_system_info();
 is(scalar(@warnings), 2, "unexcluded ext4 with $remaining free blocks/inodes still warns");
 is_deeply([ map { $_->{'level'} } @warnings ],
           [ ($remaining ? 'warn' : 'danger') x 2 ],
           'original block and inode warning thresholds are preserved');
}

# Run the unchanged raw enumeration with synthetic device/size discovery.
my $discovery_root = tempdir(CLEANUP => 1, TMPDIR => 1);
sub mount::has_command { return undef; }
sub mount::list_mounted
{
return map { [ $discovery_root.$_->{'dir'}, $_->{'device'}, $_->{'type'}, 'ro' ] } @$filesystems;
}
sub mount::disk_space
{
my ($type, $dir) = @_;
$dir =~ s/^\Q$discovery_root\E//;
my ($fs) = grep { $_->{'dir'} eq $dir } @$filesystems;
return ($fs->{'total'}/1024, $fs->{'free'}/1024,
        ($fs->{'used'} // $fs->{'total'}-$fs->{'free'})/1024);
}
sub mount::inode_space
{
my ($type, $dir) = @_;
$dir =~ s/^\Q$discovery_root\E//;
my ($fs) = grep { $_->{'dir'} eq $dir } @$filesystems;
return ($fs->{'itotal'}, $fs->{'ifree'});
}
sub mount::indexof { return status::indexof(@_); }
%mount::config = (sysinfo_exclude_types => 'udf iso9660');
my @raw_space = mount::local_disk_space();
is_deeply([ @raw_space[0,1,3] ], [2100, 700, 1330],
          'raw local_disk_space totals are unaffected by Dashboard exclusions');
is_deeply([ map { $_->{'dir'} } @{$raw_space[2]} ],
          [ map { $discovery_root.$_ } @paths ],
          'raw enumeration keeps read-only images and normal filesystems');
my @dashboard_space = mount::dashboard_disk_space();
is_deeply([ @dashboard_space[0,1,3] ], [1800, 700, 1030],
          'Dashboard wrapper filters the real raw enumerator output');

# Render the mount Dashboard table with synthetic local disk data.
sub mount::foreign_available { return $_[0] eq 'mount'; }
sub mount::load_theme_library { }
sub mount::ui_columns_start { return ''; }
sub mount::ui_columns_end { return ''; }
sub mount::ui_columns_row { return join('|', @{$_[0]})."\n"; }
sub mount::ui_text_color { return "$_[1]:$_[0]"; }
sub mount::nice_size { return $_[0]; }
{
package mount;
do "$root/mount/system_info.pl" or die "mount/system_info.pl: $@ $!";
}
{
no warnings 'redefine';
*mount::local_disk_space = sub { return (2100, 700, $filesystems, 1330); };
}
$mount::module_name = 'mount';
$mount::access{'sysinfo'} = 1;
%mount::config = ();
my @table = mount::list_system_info();
is($table[0]->{'open'}, 1, 'unfiltered full images open the disk table');
like($table[0]->{'html'}, qr/danger:0%/, 'unfiltered images receive danger styling');
%mount::config = (sysinfo_exclude_types => 'udf iso9660');
@table = mount::list_system_info();
is($table[0]->{'open'}, 0, 'excluded images do not force the disk table open');
unlike($table[0]->{'html'}, qr{/mnt/iso\||/mnt/iso/debian|danger:},
       'excluded images and their danger cells are absent');
like($table[0]->{'html'}, qr{/mnt/iso-backup}, 'unexcluded sibling remains in table');
$mount::config{'sysinfo_exclude_mount_regex'} = '.*';
is_deeply([ mount::list_system_info() ], [], 'all excluded means no disk table');

done_testing();
