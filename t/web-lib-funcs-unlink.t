#!/usr/bin/perl
# Exercise unlink_file and cached reads using only temporary fixture files.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";

# Avoid loading workstation configuration or writing Webmin debug logs.
local %main::gconfig = ();
local $main::readonly_mode_cache = 0;
local @main::filename_callbacks = ();
my $root = tempdir(CLEANUP => 1);

# write_fixture(file, contents): write directly without updating Webmin caches.
sub write_fixture
{
my ($file, $contents) = @_;
open(my $fh, '>', $file) or die "Create fixture $file: $!";
print $fh $contents or die "Write fixture $file: $!";
close($fh) or die "Close fixture $file: $!";
}

# Both readers and deletion must use the translated path as their cache key.
foreach my $translated (0, 1) {
    foreach my $recreate (0, 1) {
        my $label = ($translated ? 'translated' : 'direct').
            ($recreate ? ' recreated' : ' deleted');
        my $file = "$root/$translated-$recreate.conf";
        my $requested = $translated ? "$root/alias.conf" : $file;
        # Map the logical name to a real file entirely within the fixture tree.
        local @main::filename_callbacks = ([undef, sub {
            return $_[0] eq $requested ? $file : $_[0];
        }, []]);
        write_fixture($file, "value=old\nremoved=1\n");
        my %before;
        ok(main::read_file_cached($requested, \%before), "$label: initial read");
        is($before{value}, 'old', "$label: initial contents");
        ok(main::unlink_file($requested), "$label: deletion succeeds");
        ok(!-e $file, "$label: file is gone");
        my %after;
        if ($recreate) {
            # A new file at the same path must not inherit the old cached keys.
            write_fixture($file, "value=new\n");
            ok(main::read_file_cached($requested, \%after), "$label: new read");
            is_deeply(\%after, {value => 'new'}, "$label: only new contents");
        }
        else {
            # A successful cached read must not survive removal of its file.
            ok(!main::read_file_cached($requested, \%after), "$label: read fails");
            is_deeply(\%after, {}, "$label: no deleted contents returned");
        }
    }
}

# External writers can create a file after Webmin has cached its absence.
my $missing = "$root/missing.conf";
my %data;
ok(!main::read_file_cached($missing, \%data), 'cache a missing file');
write_fixture($missing, "value=temporary\n");
ok(main::unlink_file($missing), 'delete a file previously cached as missing');
write_fixture($missing, "value=recreated\n");
ok(main::read_file_cached($missing, \%data), 'recreated file is readable');
is_deeply(\%data, {value => 'recreated'}, 'old missing-file flag is cleared');

# A failed deletion must still report its error and process later arguments.
my @files = map { "$root/batch-$_.conf" } (1, 2);
foreach my $file (@files) {
    write_fixture($file, "value=cached\n");
    my %cached;
    ok(main::read_file_cached($file, \%cached), 'cache a batch file');
}
my ($ok, $err) = main::unlink_file("$root/absent.conf", @files);
ok(!$ok, 'batch reports a failed deletion');
ok($err, 'batch returns the deletion error');
foreach my $file (@files) {
    my %after;
    ok(!-e $file, 'batch still deletes later files');
    ok(!main::read_file_cached($file, \%after), 'later file cache is invalidated');
}

# Read-only mode must leave both the file and its cached contents available.
my $readonly = "$root/readonly.conf";
write_fixture($readonly, "value=retained\n");
my %before;
ok(main::read_file_cached($readonly, \%before), 'cache the read-only fixture');
{
    local $main::readonly_mode_cache = 1;
    ok(main::unlink_file($readonly), 'read-only call retains its success return');
}
ok(-e $readonly, 'read-only call does not delete the file');
my %after;
ok(main::read_file_cached($readonly, \%after), 'read-only file remains readable');
is_deeply(\%after, \%before, 'read-only contents remain unchanged');
done_testing();
