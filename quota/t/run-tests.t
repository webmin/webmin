#!/usr/bin/perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
my @commands;
my @responses;
our @mounted = (
	[ "/", "/dev/root", "ext4", "rw" ],
	[ "/srv/btrfs", "/dev/loop0", "btrfs", "rw" ],
	[ "/srv/btrfs/external", "/dev/loop1", "ext4", "rw" ],
	);

sub has_command
{
return $_[0] eq "btrfs" ? "/usr/bin/btrfs" : undef;
}

sub clean_language { }
sub reset_environment { }
sub is_readonly_mode { return 0; }
sub system_logged { return 0; }
sub unlink_file { return unlink($_[0]); }

sub is_under_directory
{
my ($dir, $path) = @_;
return 1 if ($dir eq "/");
$dir =~ s/\/*$/\//;
return $path eq substr($dir, 0, -1) || index($path, $dir) == 0;
}

sub next_response
{
my ($cmd) = @_;
push(@commands, $cmd);
my $response = shift(@responses) || { 'out' => "", 'status' => 0 };
$? = $response->{'status'};
return $response->{'out'};
}

sub backquote_command
{
return &next_response($_[0]);
}

sub backquote_logged
{
return &next_response($_[0]);
}

sub error
{
die join("", @_);
}

{
package mount;
sub list_mounted
{
return @main::mounted;
}
sub filesystem_for_dir
{
# Btrfs subvolumes can have a different st_dev from their containing mount,
# which prevents filesystem_for_dir from finding the mount by device number.
return @{$main::mounted[0]};
}
}

do "$root/quota/linux-lib.pl" or die "linux-lib.pl: $@ $!";

$main::config{'quotacheck_command'} = "quotacheck -ug";
$main::config{'user_quotaon_command'} = "quotaon -u";
$main::config{'group_quotaon_command'} = "quotaon -g";

my $newquota = tempdir(CLEANUP => 1);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotacheck($newquota, 1), undef,
   "new user quota file can be checked");
like($commands[1], qr/quotacheck -u -F vfsv1 /,
     "combined configured flags are replaced and new files prefer vfsv1");
unlike($commands[1], qr/ -g(?: |$)/,
       "user quota check does not also create group quotas");

my $oldquota = tempdir(CLEANUP => 1);
open(my $oldfh, '>', "$oldquota/aquota.user") or die $!;
print {$oldfh} "existing\n";
close($oldfh);
@commands = ( );
@responses = ({ 'out' => "", 'status' => 0 });
is(main::quotacheck($oldquota, 1), undef,
   "existing user quota file can be checked");
is(scalar(@commands), 1,
   "existing quota check does not probe the quota tools version");
unlike($commands[0], qr/ -F /,
       "existing quota file format is auto-detected");

my $groupquota = tempdir(CLEANUP => 1);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotacheck($groupquota, 2), undef,
   "new group quota file can be checked");
like($commands[1], qr/quotacheck -g -F vfsv1 /,
     "group-only creation also prefers vfsv1");

my $legacyquota = tempdir(CLEANUP => 1);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 3.17.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotacheck($legacyquota, 1), undef,
   "legacy quota tools can create quota files");
unlike($commands[1], qr/ -F vfsv1 /,
       "legacy quota tools retain their default format");

my $fallbackquota = tempdir(CLEANUP => 1);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "failed\n", 'status' => 1 },
	{ 'out' => "failed\n", 'status' => 1 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotacheck($fallbackquota, 1), undef,
   "quota check falls back when vfsv1 creation fails");
like($commands[3], qr/ -F vfsv0 /,
     "vfsv0 is the first creation fallback");

my $activatequota = tempdir(CLEANUP => 1);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotaon($activatequota, 1), undef,
   "new user quotas can be activated");
like($commands[1], qr/quotacheck -u -F vfsv1 /,
     "quota activation creates vfsv1 files");
unlike($commands[1], qr/ -g(?: |$)/,
       "user quota activation does not also create group quotas");

my $legacyfile = tempdir(CLEANUP => 1);
open(my $legacyfh, '>', "$legacyfile/quota.user") or die $!;
print {$legacyfh} "existing legacy quotas\n";
close($legacyfh);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotaon($legacyfile, 1), undef,
   "legacy user quota files can be activated");
like($commands[1], qr/^quotaon -u -F vfsold /,
     "legacy user quota files are activated without conversion");
ok(-s "$legacyfile/quota.user",
   "legacy user quota files are preserved");

my $legacygroup = tempdir(CLEANUP => 1);
open(my $legacygfh, '>', "$legacygroup/quota.group") or die $!;
print {$legacygfh} "existing legacy quotas\n";
close($legacygfh);
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotaon($legacygroup, 2), undef,
   "legacy group quota files can be activated");
like($commands[1], qr/^quotaon -g -F vfsold /,
     "legacy group quota files are activated without conversion");
ok(-s "$legacygroup/quota.group",
   "legacy group quota files are preserved");

my $mixedquota = tempdir(CLEANUP => 1);
foreach my $file (qw(aquota.user quota.user aquota.group quota.group)) {
	open(my $mixedfh, '>', "$mixedquota/$file") or die $!;
	print {$mixedfh} "existing quotas\n";
	close($mixedfh);
	}
@commands = ( );
@responses = (
	{ 'out' => "Quota utilities version 4.06.\n", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	{ 'out' => "", 'status' => 0 },
	);
is(main::quotaon($mixedquota, 3), undef,
   "modern quota files take precedence over stale legacy files");
unlike(join("\n", @commands), qr/ -F vfsold /,
       "stale legacy files do not override modern quota formats");

# Device-less tmpfs quota options must not create unusable filesystem rows.
is(main::quota_can([ "/tmp", "tmpfs", "tmpfs", "rw,usrquota" ], undef),
   0, "tmpfs quota mount options are ignored");
ok(main::is_btrfs_fs("/srv/btrfs"),
   "Btrfs mount point is detected");
ok(main::is_btrfs_fs("/srv/btrfs/domain1"),
   "path inside Btrfs is detected");
ok(!main::is_btrfs_fs("/srv/btrfs/external/file"),
   "nested non-Btrfs mount takes precedence");
ok(!main::is_btrfs_fs("/"),
   "non-Btrfs path is rejected");
ok(!defined(main::btrfs_quota_status("/")),
   "quota status is unavailable for non-Btrfs paths");

my $mountinfo = <<'EOF';
24 1 0:20 / / rw,relatime - ext4 /dev/root rw
31 24 0:42 /@home /home rw,relatime - btrfs /dev/vdb rw,compress=zstd
32 31 0:42 /@home/example/homes/bob /srv/bob rw,relatime - btrfs /dev/vdb rw,compress=zstd
EOF
my ($mount, $fsroot) = main::parse_btrfs_mountinfo(
	$mountinfo, "/home/example/homes/alice");
is($mount, "/home", "containing Btrfs mount is selected");
is($fsroot, '/@home', "mounted Btrfs filesystem root is returned");
is(main::btrfs_qgroup_absolute_path(
	$mount, $fsroot, '@home/example/homes/alice'),
	"/home/example/homes/alice",
	"qgroup path is translated through a mounted subvolume root");
ok(!defined(main::btrfs_qgroup_absolute_path(
	$mount, $fsroot, '@var/lib/mysql')),
	"qgroups outside the mounted filesystem root are ignored");

my $status_text = <<'EOF';
Quotas on /srv/btrfs:
  Enabled:                 yes
  Mode:                    qgroup (full accounting)
  Inconsistent:            no
  Override limits:         no
  Drop subtree threshold:  3
  Total count:             4
  Level 0:                 3
  Level 1:                 1
EOF
my $status = main::parse_btrfs_quota_status($status_text);
is_deeply($status, {
	'enabled' => 1,
	'mode' => 'qgroup',
	'mode_description' => 'full accounting',
	'inconsistent' => 0,
	'override_limits' => 0,
	'drop_subtree_threshold' => 3,
	'total_count' => 4,
	'levels' => { 0 => 3, 1 => 1 },
	}, "full Btrfs quota status is parsed");

my $simple_status = main::parse_btrfs_quota_status(<<'EOF');
Quotas on /srv/btrfs:
  Enabled:                 yes
  Mode:                    squota (simple accounting)
  Inconsistent:            yes
EOF
is($simple_status->{'mode'}, "squota", "simple quota mode is parsed");
ok($simple_status->{'inconsistent'}, "inconsistent status is parsed");
is_deeply(main::parse_btrfs_quota_status("  Enabled: no\n"),
	  { 'enabled' => 0 }, "disabled status is parsed");
ok(!defined(main::parse_btrfs_quota_status("invalid output\n")),
   "invalid status output is rejected");

@commands = ( );
@responses = ({ 'out' => $status_text, 'status' => 0 });
$status = main::btrfs_quota_status("/srv/btrfs");
ok($status->{'supported'} && $status->{'enabled'},
   "status command reports enabled quotas");
is(scalar(@commands), 1, "successful status does not run fallback");

@responses = (
	{ 'out' => "ERROR: unknown token 'status'\n", 'status' => 1 },
	{ 'out' => "qgroupid rfer excl\n0/5 16384 16384\n", 'status' => 0 },
	);
$status = main::btrfs_quota_status("/srv/btrfs");
ok($status->{'enabled'}, "legacy qgroup fallback detects enabled quotas");

my $sysfs = tempdir(CLEANUP => 1);
my $fsuuid = "12345678-1234-1234-1234-123456789abc";
make_path("$sysfs/$fsuuid/qgroups");
foreach my $pair ([ 'enabled', 1 ], [ 'mode', 'squota' ],
		  [ 'inconsistent', 1 ]) {
	open(my $fh, '>', "$sysfs/$fsuuid/qgroups/$pair->[0]") or die $!;
	print {$fh} "$pair->[1]\n";
	close($fh);
	}
local $main::btrfs_sysfs_root = $sysfs;
@responses = (
	{ 'out' => "ERROR: unknown token 'status'\n", 'status' => 1 },
	{ 'out' => "qgroupid rfer excl\n0/5 16384 16384\n", 'status' => 0 },
	{ 'out' => "Label: none  uuid: $fsuuid\n", 'status' => 0 },
	);
$status = main::btrfs_quota_status("/srv/btrfs");
is($status->{'mode'}, 'squota',
   "legacy fallback reads simple-quota mode from sysfs");
ok($status->{'inconsistent'},
   "legacy fallback reads inconsistent accounting from sysfs");

@responses = (
	{ 'out' => "ERROR: unknown token 'status'\n", 'status' => 1 },
	{ 'out' => "ERROR: quota root does not exist\n", 'status' => 1 },
	);
$status = main::btrfs_quota_status("/srv/btrfs");
is($status->{'enabled'}, 0, "legacy fallback detects disabled quotas");

my $qgroup_text = <<'EOF';
Qgroupid    Referenced    Exclusive  Max referenced  Max exclusive Parent   Child         Path
--------    ----------    ---------  --------------  ------------- ------   -----         ----
0/5              16384        16384            none           none ---      ---           <toplevel>
0/256            16384        16384        67108864           none 1/100    -             domain1
0/257                0            0            none       33554432 1/100    -             domain two
1/100            16384        16384       100663296           none -        0/256,0/257   <0 member qgroups>
EOF
my $qgroups = main::parse_btrfs_qgroup_output($qgroup_text);
is(scalar(@$qgroups), 4, "all qgroups are parsed");
is_deeply($qgroups->[0]->{'parents'}, [ ],
	  "legacy empty parent marker is parsed");
is_deeply($qgroups->[0]->{'children'}, [ ],
	  "legacy empty child marker is parsed");
is($qgroups->[1]->{'max_referenced'}, 67108864,
   "referenced limit is parsed as bytes");
ok(!defined($qgroups->[1]->{'max_exclusive'}),
   "missing exclusive limit is undef");
is_deeply($qgroups->[1]->{'parents'}, [ "1/100" ],
          "parent qgroup is parsed");
is($qgroups->[2]->{'path'}, "domain two",
   "subvolume paths containing spaces are preserved");
is_deeply($qgroups->[3]->{'children'}, [ "0/256", "0/257" ],
          "multiple child qgroups are parsed");

@commands = ( );
@responses = ({ 'out' => $qgroup_text, 'status' => 0 });
my $list_error;
$qgroups = main::list_btrfs_qgroups("/srv/btrfs", 1, \$list_error);
is(scalar(@$qgroups), 4, "qgroup list command output is returned");
ok(!defined($list_error), "successful qgroup list clears the error");
like($commands[0], qr/qgroup show .*\\-\\-sync .*srv.*btrfs/,
     "synchronized qgroup listing requests --sync");

my $legacy_qgroup_text = <<'EOF';
Qgroupid Referenced Exclusive Max_referenced Max_exclusive Parent Child
0/256 16384 16384 67108864 none 1/100 -
0/257 0 0 none 33554432 1/100 -
1/100 16384 16384 100663296 none - 0/256,0/257
EOF
@commands = ( );
@responses = (
	{ 'out' => $legacy_qgroup_text, 'status' => 0 },
	{ 'out' => "ID 256 gen 10 top level 5 path domain1\n".
		   "ID 257 gen 11 top level 5 path domain path two\n",
	  'status' => 0 },
	);
$qgroups = main::list_btrfs_qgroups("/srv/btrfs", 0, \$list_error);
is($qgroups->[0]->{'path'}, "domain1",
   "legacy qgroup rows gain paths from the subvolume list");
is($qgroups->[1]->{'path'}, "domain path two",
   "legacy subvolume paths containing spaces and path are preserved");
like($commands[1], qr/subvolume list .*srv.*btrfs/,
     "legacy qgroup output triggers one compatibility lookup");

@responses = ({ 'out' => "ERROR: quotas not enabled\n", 'status' => 1 });
$qgroups = main::list_btrfs_qgroups("/srv/btrfs", 0, \$list_error);
ok(!defined($qgroups), "failed qgroup listing returns undef");
like($list_error, qr/quotas not enabled/,
     "failed qgroup listing returns the command error");
@responses = ({ 'out' => "unexpected output\n", 'status' => 0 });
$qgroups = main::list_btrfs_qgroups("/srv/btrfs", 0, \$list_error);
ok(!defined($qgroups), "unparseable qgroup listing returns undef");
is($list_error, "Unable to parse Btrfs qgroup output",
   "unparseable qgroup output is reported");

@responses = ({
	'out' => "domain1\n\tSubvolume ID:\t\t256\n",
	'status' => 0,
	});
is(main::btrfs_subvolume_id("/srv/btrfs/domain1"), 256,
   "subvolume ID is parsed");

@responses = (
	{ 'out' => "domain1\n\tSubvolume ID:\t\t256\n", 'status' => 0 },
	{ 'out' => $qgroup_text, 'status' => 0 },
	);
my $qgroup = main::get_btrfs_qgroup("/srv/btrfs/domain1", 0);
is($qgroup->{'id'}, "0/256", "subvolume qgroup is selected by ID");

@commands = ( );
@responses = map { { 'out' => "", 'status' => 0 } } 1 .. 9;
is(main::enable_btrfs_quotas("/srv/btrfs", 1), undef,
   "simple quotas can be enabled");
is(main::set_btrfs_qgroup_limit("/srv/btrfs", "1/100", 1048576, 0),
   undef, "referenced qgroup limit can be set");
is(main::set_btrfs_qgroup_limit("/srv/btrfs/domain1", undef, undef, 1),
   undef, "exclusive subvolume limit can be removed");
is(main::create_btrfs_qgroup("/srv/btrfs", "1/101"), undef,
   "parent qgroup can be created");
is(main::assign_btrfs_qgroup("/srv/btrfs", "0/256", "1/101"), undef,
   "child qgroup can be assigned");
is(main::unassign_btrfs_qgroup("/srv/btrfs", "0/256", "1/101"), undef,
   "child qgroup can be unassigned");
is(main::delete_btrfs_qgroup("/srv/btrfs", "1/101"), undef,
   "parent qgroup can be deleted");
is(main::rescan_btrfs_quotas("/srv/btrfs", 1), undef,
   "quota rescan can run and wait");
is(main::disable_btrfs_quotas("/srv/btrfs"), undef,
   "Btrfs quotas can be disabled");
like($commands[0], qr/quota enable .*\\-\\-simple/,
     "simple enable command uses supported long option");
like($commands[1], qr/qgroup limit .*1048576 .*1\\\/100/,
     "referenced limit command contains size and qgroup");
like($commands[2], qr/qgroup limit .*\-e .*none/,
     "exclusive limit removal uses -e and none");
like($commands[7], qr/quota rescan .*\\-w/,
     "quota rescan uses the portable short wait option");

is(main::set_btrfs_qgroup_limit("/srv/btrfs", "bad", 1024),
   "Invalid Btrfs qgroup ID", "invalid qgroup IDs are rejected");
is(main::disable_btrfs_quotas("relative/path"),
   "Invalid Btrfs path", "relative paths are rejected");
is(main::disable_btrfs_quotas("/srv/btrfs\n/etc"),
   "Invalid Btrfs path", "paths with control characters are rejected");
ok(!main::is_btrfs_fs("/srv/btrfs\n/etc"),
   "paths with control characters are not detected as Btrfs");
is(main::set_btrfs_qgroup_limit("/srv/btrfs", "1/100", "1M"),
   "Invalid Btrfs qgroup limit", "non-byte limits are rejected");
is(main::assign_btrfs_qgroup("/srv/btrfs", "bad", "1/100"),
   "Invalid child Btrfs qgroup ID", "invalid child assignment is rejected");

@commands = ( );
@responses = ({ 'out' => "ERROR: unable to limit requested quota group: ".
			 "Disk quota exceeded\n", 'status' => 1 });
like(main::set_btrfs_qgroup_limit("/srv/btrfs", "1/100", 2097152),
     qr/Disk quota exceeded/, "qgroup limit errors are returned without retry");
is(scalar(@commands), 1, "a failed qgroup limit command is not retried");

@responses = ({ 'out' => "ERROR: qgroup exists\n", 'status' => 1 });
is(main::create_btrfs_qgroup("/srv/btrfs", "1/100"),
   "ERROR: qgroup exists", "Btrfs command errors are returned to callers");

done_testing();
