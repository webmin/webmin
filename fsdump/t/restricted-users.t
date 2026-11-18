#!/usr/bin/perl
# Checks the limits applied to fsdump users who cannot run commands or who
# are limited to some directories.

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
$tmp = abs_path($tmp);
my $confdir = "$tmp/etc";
my $vardir = "$tmp/var";
make_path("$confdir/fsdump", "$confdir/mount", $vardir);

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
$ENV{'FOREIGN_MODULE_NAME'} = 'fsdump';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;
chdir("$rootdir/fsdump") or die "chdir: $!";
require "$rootdir/fsdump/fsdump-lib.pl";

# Errors die, so tests can catch them
{
no warnings 'redefine';
*main::error = sub { die "ERROR: ".join("", @_)."\n" };
}

# Unrestricted admins keep every option
%main::access = ( 'cmds' => 1, 'dirs' => '*', 'extra' => 1 );
is(main::extra_args_error('tar', 0, '--to-command=id -C /etc'), undef,
   'admins can use any tar option');

# Users who cannot run commands
%main::access = ( 'cmds' => 0, 'dirs' => '*', 'extra' => 1 );
foreach my $opt ('--checkpoint-action=exec=id', '--to-command=id',
		 '--use-compress-program=id', '-Iid', '-vI', '--rsh-command=x',
		 '--rmt-command=x', '--info-script=x', '-F', '--new-volume=x',
		 '--to-com=id', '--') {
	like(main::extra_args_error('tar', 0, $opt), qr/run other programs/,
	     "tar option $opt is refused without command access");
	}
like(main::extra_args_error('ext4', 1, '-F /tmp/x'), qr/run other programs/,
     'restore -F is refused without command access');
like(main::extra_args_error('xfs', 0, '-c /tmp/x'), qr/run other programs/,
     'xfsdump -c is refused without command access');
is(main::extra_args_error('tar', 0, '--exclude=*.tmp --checkpoint=100 -v'),
   undef, 'harmless tar options are kept');
is(main::extra_args_error('tar', 0, '-C /etc'), undef,
   'directory options are allowed when all directories are allowed');

# Users limited to some directories
%main::access = ( 'cmds' => 1, 'dirs' => "$tmp/allowed", 'extra' => 1 );
foreach my $opt ('-C /etc', '--directory=/etc', '--file=/etc/x', '-P',
		 '--absolute-names', '-h', '--files-from=/etc/list',
		 '--same-owner', '-p', '/etc/shadow', '--di=/etc') {
	like(main::extra_args_error('tar', 1, $opt), qr/outside the directories/,
	     "tar option $opt is refused for restricted directories");
	}
like(main::extra_args_error('ext4', 0, '-f /etc/x'),
     qr/outside the directories/, 'dump -f is refused');
is(main::extra_args_error('tar', 0, '--exclude=*.tmp -v'), undef,
   'harmless tar options are kept for restricted users');

# Custom rsh programs need command access
%main::access = ( 'cmds' => 0, 'dirs' => '*' );
%main::in = ( 'rsh_def' => 2, 'rsh' => '/bin/sh -c id' );
ok(!eval { main::rsh_command_parse('rsh_def', 'rsh'); 1 },
   'custom rsh program is refused without command access');
is(main::rsh_command_parse('rsh_def', 'rsh', '/bin/sh -c id'),
   '/bin/sh -c id', 'unchanged custom rsh program is kept');
%main::access = ( 'cmds' => 1, 'dirs' => '*' );
is(main::rsh_command_parse('rsh_def', 'rsh'), '/bin/sh -c id',
   'admins can set a custom rsh program');

# Destinations for directory-limited users
make_path("$tmp/allowed", "$tmp/other");
write_file("$tmp/other/secret", "secret\n");
symlink("$tmp/other/secret", "$tmp/allowed/link") or die "symlink: $!";
%main::access = ( 'cmds' => 0, 'dirs' => "$tmp/allowed" );
ok(main::can_use_dump_file("$tmp/allowed/backup.tar"),
   'file in an allowed directory can be used');
ok(!main::can_use_dump_file("$tmp/allowed/link"),
   'symlink leaving the allowed directory cannot be used');
ok(!main::can_use_dump_file("/dev/null"),
   'other devices cannot be used');
ok(!main::is_tape_device("/dev/st0x"), 'invalid tape name is rejected');
ok(!main::is_tape_device("/dev/rmt/../mem"),
   'tape path traversal is rejected');
ok(!main::is_tape_device("$tmp/allowed/nst0"),
   'tape names outside /dev are rejected');

# An allowed directory replaced by a symlink does not grant its target
symlink("$tmp/other", "$tmp/allowed/sub") or die "symlink: $!";
%main::access = ( 'cmds' => 0, 'dirs' => "$tmp/allowed/sub" );
ok(!main::can_edit_dir("$tmp/allowed/sub"),
   'allowed directory that is a symlink is not followed');
ok(!main::can_edit_dir("$tmp/other"), 'target of the symlink is refused');
%main::access = ( 'cmds' => 0, 'dirs' => "$tmp/allowed" );

# Use the same directory list for ACL checks and execution, including jobs
# saved before tar backups used tabs to separate paths containing spaces.
my $job = { fs => 'tar', tabs => 1 };
$job->{'dir'} = "$tmp/allowed/first dir\t$tmp/allowed/second dir";
ok(main::can_edit_dir($job), 'all directories in a permitted job are accepted');
$job->{'dir'} .= "\t$tmp/other";
ok(!main::can_edit_dir($job), 'one unlisted directory denies the job');
delete($job->{'tabs'});
$job->{'dir'} = "$tmp/allowed/first $tmp/other";
ok(!main::can_edit_dir($job), 'legacy jobs check every directory too');
$job->{'dir'} = '';
ok(!main::can_edit_dir($job), 'empty job has no permitted directory');
is(main::restore_file_arguments('./report'), quotemeta('./report'),
   'a relative member stays selectable');
ok(!eval { main::restore_file_arguments("$tmp/other"); 1 },
   'directory-limited restores require relative member names');

my $dump = { 'file' => "$tmp/allowed/link", 'ownerdirs' => "$tmp/allowed" };
ok(!main::dump_dest_allowed($dump), 'scheduled run refuses a link outside its grant');
symlink("backup.tar", "$tmp/allowed/current") or die "symlink: $!";
$dump->{'file'} = "$tmp/allowed/current";
ok(main::dump_dest_allowed($dump), 'scheduled run accepts a link inside its grant');
$dump->{'file'} = "$tmp/allowed/backup.tar";
ok(main::dump_dest_allowed($dump), 'scheduled run allows a plain file');
$dump->{'file'} = "$tmp/other/backup.tar";
ok(!main::dump_dest_allowed($dump),
   'scheduled run refuses a file outside the saved directories');
delete($dump->{'ownerdirs'});
ok(main::dump_dest_allowed($dump), 'admin backups are not limited');

done_testing();
