#!/usr/bin/perl
# Checks who may use the raw crontab editor. A module-wide hourly limit does
# not block full admins, but an hourly limit in the user's own ACL does.

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
my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);

# write_file(path, content)
# Creates a test file with the given content
sub write_file
{
my ($path, $data) = @_;
open(my $fh, ">", $path) or die "$path: $!";
print $fh $data;
close($fh);
}

make_path("$confdir/cron");
write_file("$confdir/config", "os_type=generic-linux\nos_version=0\n");
write_file("$confdir/var-path", "$vardir\n");
write_file("$confdir/miniserv.conf", "root=$rootdir\n");
write_file("$confdir/cron/config", "hourly_only=1\n");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'cron';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;
chdir("$rootdir/cron") or die "chdir: $!";
require "$rootdir/cron/cron-lib.pl";

my %full = ( 'mode' => 0, 'command' => 1, 'create' => 1, 'delete' => 1,
	     'env' => 1, 'move' => 1 );

# Default ACL follows the module-wide hourly limit
%main::access = ( %full, 'hourly' => 2 );
$main::hourly_only = 1;
ok(main::can_edit_cron_files(),
   'full admin keeps the editor when the module config limits jobs');

# Hourly limit set for this user
%main::access = ( %full, 'hourly' => 1 );
ok(!main::can_edit_cron_files(),
   'user with an hourly limit in their ACL loses the editor');

# Missing job permissions still block the editor
%main::access = ( %full, 'hourly' => 0, 'command' => 0 );
$main::hourly_only = 0;
ok(!main::can_edit_cron_files(),
   'user who cannot set commands loses the editor');

done_testing();
