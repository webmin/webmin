#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

plan skip_all => 'requires an explicitly enabled Linux Webmin guest'
	unless $ENV{'WEBMIN_BACKUP_CONFIG_VM_TEST'} && $^O eq 'linux' &&
	       -f '/etc/webmin/miniserv.conf';

my $src = abs_path("$FindBin::Bin/..");
@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR REMOTE_USER SERVER_ROOT LIBROOT SCRIPT_NAME)} =
	('/etc/webmin', '/var/webmin', 'root', $src, $src, '/backup-config/test.cgi');
unshift(@INC, $src, "$src/vendor_perl");
chdir("$src/backup-config") or die $!;
require './backup-config-lib.pl';
require "$src/t/test-lib.pl";

my $tmp = tempdir('webmin-backup-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my ($one, $dir, $archive) = ("$tmp/one", "$tmp/data", "$tmp/backup.tar");
make_path($dir, "$tmp/work area");
our %gconfig;
local $gconfig{'tempdir'} = "$tmp/work area";
my $which = \&has_command;

# Check backups made on systems both with and without gzip.
for my $compressed (0, 1) {
	SKIP: {
	skip 'gzip unavailable', 1 if $compressed && !$which->('gzip');
	my $label = $compressed ? 'compressed archive' : 'plain archive';
	subtest $label => sub {
		no warnings 'redefine';
		local *main::has_command = sub {
			return undef if !$compressed && $_[0] eq 'gzip';
			return &$which;
			};
		write_text($one, "first\n");
		write_text("$dir/two", "second\n");
		is(execute_backup([], $archive, undef, undef, 0, 1, [$one, $dir]),
		   undef, 'backs up a file and directory') or return;
		is(!!(substr(read_text($archive), 0, 2) eq "\037\213"),
		   !!$compressed, 'writes the expected archive format');
		write_text($one, "changed\n");
		write_text("$dir/two", "preserve\n");
		my @names;
		is(execute_restore([], $archive, \@names, 0, 1, [$dir]), undef,
		   'previews a selected directory');
		is_deeply(\@names, [substr("$dir/two", 1)], 'lists just its contents');
		is(execute_restore([], $archive, \@names, 0, 0, [$one]), undef,
		   'restores one selected file');
		is(read_text($one), "first\n", 'selected file restored');
		is(read_text("$dir/two"), "preserve\n", 'other file kept');
		is(execute_restore([], $archive, \@names, 0, 0, [$dir]), undef,
		   'restores selected directory');
		is(read_text("$dir/two"), "second\n", 'directory contents restored');
		};
	}
	}

my @names;
SKIP: {
	skip 'gzip unavailable', 2 unless $which->('gzip');
	# A selected file can disappear between listing it and running tar.
	no warnings 'redefine';
	my $run = \&execute_command;
	my $vanished = "$tmp/vanished";
	write_text($vanished, "temporary\n");
	write_text($archive, "previous backup\n");
	local *main::execute_command = sub {
		unlink($vanished) if ($_[0] =~ /\btar cfT /);
		return &$run;
		};
	ok(execute_backup([], $archive, undef, undef, 0, 1, [$one, $vanished]),
	   'a failed tar is reported even when gzip succeeds');
	is(read_text($archive), "previous backup\n", 'keeps the previous backup');
	}

system('tar', 'cf', $archive, '-C', '/', substr($one, 1)) == 0 or die $!;
write_text($one, "changed\n");
is(execute_restore([], $archive, \@names, 0, 0, [$one]), undef,
   'restores an explicitly named member without a manifest');
is(read_text($one), "first\n", 'restores data from older backups');
done_testing();
