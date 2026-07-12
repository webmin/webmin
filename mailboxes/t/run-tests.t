#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
my $tmp = tempdir(CLEANUP => 1);

our (%config, %userconfig, $module_config_directory, $module_var_directory,
     $user_module_config_directory);
$module_config_directory = "$tmp/config";
$module_var_directory = "$tmp/var";
make_path($module_config_directory, $module_var_directory);

sub make_dir
{
my ($dir, $mode) = @_;
make_path($dir, { mode => $mode });
return -d $dir;
}

sub error
{
die join("", @_), "\n";
}

sub open_tempfile
{
my ($fh, $file) = @_;
no strict 'refs';
open($fh, $file) || die "open_tempfile $file: $!";
}

sub close_tempfile
{
my ($fh) = @_;
no strict 'refs';
close($fh) || die "close_tempfile: $!";
}

sub set_ownership_permissions
{
return 1;
}

require "$root/mailboxes/boxes-lib.pl";
require "$root/mailboxes/folders-lib.pl";

sub write_file
{
my ($file, $text) = @_;
open(my $fh, ">", $file) || die "write $file: $!";
print $fh $text;
close($fh) || die "close $file: $!";
}

subtest 'count_maildir' => sub {
	my $missing = "$tmp/missing/Maildir";
	is(count_maildir($missing), 0, 'missing Maildir counts as empty');

	my $maildir = "$tmp/user/Maildir";
	make_path("$maildir/cur", "$maildir/new", "$maildir/tmp");
	write_file("$maildir/cur/1", "Subject: one\n\nbody\n");
	write_file("$maildir/new/2", "Subject: two\n\nbody\n");
	write_file("$maildir/tmp/3", "Subject: temp\n\nbody\n");
	is(count_maildir($maildir), 2, 'cur and new messages are counted');

	my $broken = "$tmp/broken/Maildir";
	make_path($broken);
	my $ok = eval { count_maildir($broken); 1 };
	ok(!$ok, 'malformed existing Maildir still fails');
	like($@, qr/Failed to open \Q$broken\/cur\E/,
	     'missing cur directory reports the existing error');

	my $notdir = "$tmp/notdir/Maildir";
	make_path("$tmp/notdir");
	write_file($notdir, "not a maildir\n");
	$ok = eval { count_maildir($notdir); 1 };
	ok(!$ok, 'non-directory Maildir path still fails');
	like($@, qr/Failed to open \Q$notdir\/cur\E/,
	     'non-directory Maildir path reports the existing error');

	SKIP: {
		my $link = "$tmp/link/Maildir";
		make_path("$tmp/link");
		skip 'symlink unavailable', 2
			if (!symlink("$tmp/no-such-target", $link));
		$ok = eval { count_maildir($link); 1 };
		ok(!$ok, 'dangling Maildir symlink still fails');
		like($@, qr/Failed to open \Q$link\/cur\E/,
		     'dangling Maildir symlink reports the existing error');
		}
	};

subtest 'mailbox_uncompress_folder skips invalid Maildir subfolders' => sub {
	my $maildir = "$tmp/uncompress/Maildir";
	make_path("$maildir/cur", "$maildir/new", "$maildir/tmp");

	# A valid Maildir++ subfolder should still be scanned.
	make_path("$maildir/.Archive/cur", "$maildir/.Archive/new",
		  "$maildir/.Archive/tmp");

	# A partial Maildir must be skipped because get_maildir_files reads both
	# cur and new unconditionally.
	make_path("$maildir/.Partial/cur");
	my $ok = eval {
		mailbox_uncompress_folder({ 'type' => 1, 'file' => $maildir });
		1;
		};
	ok($ok, 'partial Maildir++ entries are ignored');

	SKIP: {
		skip 'symlink unavailable', 1
			if (!symlink("$tmp/no-such-target", "$maildir/.Alias"));
		$ok = eval {
			mailbox_uncompress_folder({ 'type' => 1,
						    'file' => $maildir });
			1;
			};
		ok($ok, 'dangling Maildir++ symlinks are ignored');
		}
	};

done_testing();
