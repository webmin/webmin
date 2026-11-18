#!/usr/bin/perl
# Checks that numeric user and group IDs cannot bypass quota ACL lists, and
# that copying quotas respects the maximum limits.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $bindir = abs_path($0);
$bindir =~ s{/[^/]+$}{};
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";
my $tmp = tempdir(CLEANUP => 1);
my $confdir = "$tmp/etc";
my $vardir = "$tmp/var";
make_path("$confdir/quota", "$confdir/mount", $vardir);

# write_file(path, content)
# Creates a test file with the given content
sub write_file
{
my ($path, $data) = @_;
open(my $fh, ">", $path) or die "$path: $!";
print $fh $data;
close($fh);
}

write_file("$confdir/config", "os_type=generic-linux\nos_version=0\n");
write_file("$confdir/var-path", "$vardir\n");
write_file("$confdir/miniserv.conf", "root=$rootdir\n");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'quota';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;
chdir("$rootdir/quota") or die "chdir: $!";
require "$rootdir/quota/quota-lib.pl";

my @root = getpwuid(0);
my @other = getpwuid(1);
plan skip_all => 'UID 1 is needed for these tests' if (!@other);
my ($rname, $oname, $ogid) = ($root[0], $other[0], $other[3]);
my $rgroup = getgrgid(0);

# Users excluded by name are also excluded by UID
%main::access = ( 'umode' => 2, 'users' => $rname );
ok(!main::can_edit_user($rname), 'excluded user is refused');
ok(!main::can_edit_user('#0'), 'excluded user is refused as #UID');
ok(!main::can_edit_user('0'), 'excluded user is refused as plain UID');
ok(main::can_edit_user($oname), 'other user is allowed');
ok(main::can_edit_user('#1'), 'other user is allowed as #UID');

# Users allowed by name are also allowed by UID
%main::access = ( 'umode' => 1, 'users' => $oname );
ok(main::can_edit_user('#1'), 'listed user is allowed as #UID');
ok(!main::can_edit_user('#0'), 'unlisted user is refused as #UID');
ok(!main::can_edit_user($rname), 'unlisted user is refused');

# UID ranges use the real UID
%main::access = ( 'umode' => 4, 'umin' => 1, 'umax' => '' );
ok(!main::can_edit_user('#0'), 'UID below the range is refused');
ok(!main::can_edit_user('0'), 'plain UID below the range is refused');
ok(main::can_edit_user($oname), 'user in the range is allowed');
ok(!main::can_edit_user('no-such-user-xyz'), 'unknown user is refused');

# Primary group limits use the account behind a UID
%main::access = ( 'umode' => 3, 'users' => $ogid );
ok(main::can_edit_user('#1'), 'user in the group is allowed as #UID');

# Groups excluded by name are also excluded by GID
SKIP: {
	skip('GID 0 has no name', 3) if (!$rgroup);
	%main::access = ( 'gmode' => 2, 'groups' => $rgroup );
	ok(!main::can_edit_group($rgroup), 'excluded group is refused');
	ok(!main::can_edit_group('#0'), 'excluded group is refused as #GID');
	ok(!main::can_edit_group('0'), 'excluded group is refused as GID');
}

# Copying quotas checks the source limits
{
no warnings 'redefine';
my @fs;
my @mounted;
*main::error = sub { die "ERROR: ".join("", @_)."\n" };
*main::user_filesystems = sub {
	for(my $i=0; $i<@fs; $i++) {
		foreach my $k (keys %{$fs[$i]}) {
			$main::filesys{$i,$k} = $fs[$i]->{$k};
			}
		}
	return scalar(@fs);
	};
*main::list_filesystems = sub { return @mounted };

%main::access = ( 'maxblocks' => 100, 'maxfiles' => 0 );
@fs = ( { 'filesys' => '/home', 'sblocks' => 50, 'hblocks' => 100,
	  'sfiles' => 0, 'hfiles' => 0 } );
ok(eval { main::check_copy_limits($oname, 0); 1 },
   'limits within the maximum can be copied');
$fs[0]->{'hblocks'} = 0;
ok(!eval { main::check_copy_limits($oname, 0); 1 },
   'an unlimited source cannot be copied');
$fs[0]->{'hblocks'} = 500;
ok(!eval { main::check_copy_limits($oname, 0); 1 },
   'a source above the maximum cannot be copied');
$fs[0]->{'hblocks'} = 100;
@mounted = ( [ '/srv', '/dev/sdb1', 'ext4', 'usrquota', 1, 1 ] );
ok(!eval { main::check_copy_limits($oname, 0); 1 },
   'a filesystem without source limits would be copied as unlimited');
%main::access = ( );
ok(eval { main::check_copy_limits($oname, 0); 1 },
   'users without maximums are not limited');
}

done_testing();
