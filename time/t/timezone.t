#!/usr/bin/perl
# Checks which time zones can be saved: listed zones and zone files with plain
# names are accepted, names that could inject config lines are refused.

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
my $zdir = "$tmp/zoneinfo";
make_path("$confdir/time", "$confdir/webmincron", $vardir,
	  "$zdir/Etc", "$zdir/America/Argentina");

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
write_file("$confdir/time/config", "zone_style=linux\n");

# A zone list without Etc/UTC, plus zone files on disk
write_file("$zdir/zone.tab",
	   "AR\t-3436-05827\tAmerica/Argentina/Buenos_Aires\n");
write_file("$zdir/America/Argentina/Buenos_Aires", "TZif");
write_file("$zdir/Etc/UTC", "TZif");
write_file("$tmp/outside", "TZif");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'time';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;
chdir("$rootdir/time") or die "chdir: $!";
require "$rootdir/time/time-lib.pl";
$main::timezones_file = "$zdir/zone.tab";
$main::timezones_dir = $zdir;
$main::currentzone_link = "$tmp/localtime";
symlink("$zdir/Etc/UTC", "$tmp/localtime") or die "symlink: $!";

ok(main::valid_timezone('America/Argentina/Buenos_Aires'),
   'zone from the zone list is accepted');
ok(main::valid_timezone('UTC'), 'built-in UTC entry is accepted');
ok(main::valid_timezone('Etc/UTC'),
   'current zone file missing from the zone list is accepted');
ok(!main::valid_timezone(''), 'empty zone is refused');
ok(!main::valid_timezone('Etc/Nowhere'), 'missing zone file is refused');
ok(!main::valid_timezone('../outside'), 'parent directory is refused');
ok(!main::valid_timezone('Etc/../../outside'),
   'parent directory inside the name is refused');
ok(!main::valid_timezone("UTC\"\nCLOCKFLAGS=\"--utc;id"),
   'quotes and line breaks are refused');
ok(!main::valid_timezone('/etc/passwd'), 'absolute path is refused');
ok(!main::valid_timezone("Etc/UTC\n"), 'trailing line break is refused');

done_testing();
