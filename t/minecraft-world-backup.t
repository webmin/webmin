#!/usr/bin/perl
# Check backup retention when worlds move or change their directory layout.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/t/test-lib.pl";
require "$root/web-lib-funcs.pl";
plan skip_all => 'requires zip and unzip' if
	grep { !main::has_command($_) } qw(zip unzip);

# Load world discovery and the scheduled backup without a host installation.
{
	local $INC{'WebminCore.pm'} = 1;
	local *main::init_config = sub { };
	local *main::foreign_require = sub { };
	require "$root/minecraft/minecraft-lib.pl";
}
local *main::is_minecraft_server_running = sub { 0 };
local *main::is_readonly_mode = sub { 0 };
local $main::null_file = '/dev/null';
my $tmp = tempdir('webmin-worlds-XXXXXXXX', DIR => '/tmp', CLEANUP => 1);
local $main::gconfig{'tempdir'} = "$tmp/webmin-temp";
my $server = "$tmp/server";
my $backups = "$tmp/backups";
local %main::config = (minecraft_dir => $server, backup_dir => $backups,
		       unix_user => 'root');
local %main::text;
main::read_file("$root/minecraft/lang/en", \%main::text);
make_path("$server/Existing", "$server/Healthy", $backups);
write_text("$server/Existing/level.dat", "original world\n");
write_text("$server/Healthy/level.dat", "first version\n");
write_text("$server/Healthy/region.mca", "region data\n");

my ($report, $failed) = main::execute_backup_worlds();
is($failed, 0, 'backs up both world directories');
my $zip = "$backups/Existing.zip";
my $saved = read_text($zip);
ok(length($saved), 'initial backup exists');
is((stat($zip))[2] & 0777, 0755, 'a new backup has its configured permissions');
chmod(0640, $zip) or die $!;

# One linked world has a full backup already. The other has none.
rename("$server/Existing", "$tmp/relocated") or die $!;
symlink("$tmp/relocated", "$server/Existing") or die $!;
symlink("$tmp/relocated", "$server/NewLink") or die $!;
write_text("$server/Healthy/level.dat", "updated healthy world\n");
unlink("$server/Healthy/region.mca") or die $!;
($report, $failed) = main::execute_backup_worlds();
is($failed, 2, 'counts each linked world as a failed backup');
for my $name (qw(Existing NewLink)) {
	like(join("\n", @$report), qr/Backing up \Q$name\E .*\n[^\n]*symbolic link/i,
	     "report explains why $name was skipped");
	}
ok(read_text($zip) eq $saved, 'preserves the previous backup byte for byte');
is((stat($zip))[2] & 0777, 0640, 'preserves its permissions');
ok(!-e "$backups/NewLink.zip", 'creates no backup for a new linked world');
open(my $entry, '-|', 'unzip', '-p', "$backups/Healthy.zip", 'Healthy/level.dat')
	or die $!;
is(<$entry>, "updated healthy world\n", 'still updates the ordinary world');
ok(close($entry), 'the updated world is readable');
open(my $kept, '-|', 'unzip', '-p', "$backups/Healthy.zip", 'Healthy/region.mca')
	or die $!;
is(<$kept>, "region data\n", 'keeps files later deleted from the world');
close($kept);

# A running world is flushed and resumed. A replacement server starts with
# its own save state and must not receive a command from the previous backup.
write_text("$server/server.properties", "level-name=Healthy\n");
local $main::config{'backup_worlds'} = 'Healthy';
for my $after (123, 456) {
	my @pids = (123, $after);
	my @commands;
	local *main::is_minecraft_server_running = sub { shift(@pids) };
	local *main::execute_minecraft_command = sub { push(@commands, $_[0]) };
	(undef, $failed) = main::execute_backup_worlds();
	is($failed, 0, 'backs up the active world');
	is_deeply(\@commands, $after == 123 ? [qw(save-off save-all save-on)] :
					     [qw(save-off save-all)],
		  "resumes writes only on the original server (PID $after)");
	}

# A reused ZIP must still extract after a path changes between file and folder.
for my $change (qw(directory-to-file directory-to-link file-to-directory)) {
	subtest $change => sub {
		my $world = "$server/$change";
		my $path = "$world/maps";
		my $archive = "$backups/$change.zip";
		local $main::config{'backup_worlds'} = $change;
		make_path($world);
		write_text("$world/level.dat", "level\n");
		if ($change eq 'file-to-directory') {
			write_text($path, "old file\n");
			}
		else {
			make_path($path);
			write_text("$path/guide.txt", "old map\n");
			}
		(undef, $failed) = main::execute_backup_worlds();
		is($failed, 0, 'initial backup succeeds');
		my $original = read_text($archive);

		if ($change eq 'file-to-directory') {
			unlink($path) or die $!;
			make_path($path);
			write_text("$path/guide.txt", "new map\n");
			}
		else {
			rename($path, "$world/old-maps") or die $!;
			if ($change eq 'directory-to-link') {
				symlink('old-maps', $path) or die $!;
				}
			else {
				write_text($path, "new file\n");
				}
			}
		($report, $failed) = main::execute_backup_worlds();
		is($failed, 1, 'reports the incompatible update as a failure');
		like(join("\n", @$report), qr/Choose a new backup destination/,
		     'explains how to back up the new layout');
		ok(read_text($archive) eq $original, 'preserves the previous ZIP');

		local $main::config{'backup_dir'} = "$tmp/new backups";
		(undef, $failed) = main::execute_backup_worlds();
		is($failed, 0, 'a fresh backup succeeds');
		my $restore = "$tmp/restored";
		make_path($restore);
		is(system('unzip', '-oq', "$tmp/new backups/$change.zip",
			  '-d', $restore), 0, 'the new layout restores');
		my $restored = "$restore/$change/maps";
		if ($change eq 'directory-to-link') {
			is(readlink($restored), 'old-maps', 'restores the updated link');
			}
		elsif ($change eq 'file-to-directory') {
			is(read_text("$restored/guide.txt"), "new map\n", 'restores the new map');
			}
		else {
			is(read_text($restored), "new file\n", 'restores the new file');
			}
		};
	}

# An administrator may have linked one backup filename to an older snapshot.
my $healthy_zip = "$backups/Healthy.zip";
rename($healthy_zip, "$tmp/previous.zip") or die $!;
symlink("$tmp/previous.zip", $healthy_zip) or die $!;
my $previous = read_text("$tmp/previous.zip");
($report, $failed) = main::execute_backup_worlds();
is($failed, 1, 'reports a linked backup destination');
like(join("\n", @$report), qr/existing backup must be a regular ZIP file/,
     'explains how to back up a world with a linked destination');
ok(-l $healthy_zip && read_text("$tmp/previous.zip") eq $previous,
   'preserves the backup link and its target');
done_testing();
