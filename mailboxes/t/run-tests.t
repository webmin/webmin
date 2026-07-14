#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use POSIX ();

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
my $tmp = tempdir(CLEANUP => 1);

our (%config, %userconfig, $module_config_directory, $module_var_directory,
     $user_module_config_directory, %in, %gconfig, %access, %global_access,
     $root_directory, $remote_user, $current_theme);
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
require "$root/mailboxes/xhr-lib.pl";

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

subtest 'XHR remote content uses global destination ACL' => sub {
	my $pid = fork();
	if (!defined($pid)) {
		plan skip_all => 'fork unavailable';
		}
	if (!$pid) {
		no warnings qw(once redefine);
		%in = (
			'action' => 'fetch',
			'type' => 'download',
			'subtype' => 'blob',
			'url' => 'http://example.test/image.png',
			);
		%global_access = (
			'download_address_mode' => 'listed',
			'download_allowed_addresses' => '10.0.0.0/8',
			);
		local *html_unescape = sub { return $_[0]; };
		local *parse_http_url = sub {
			return ('example.test', 80, '/image.png', 0);
			};
		my $address_checker = sub {
			POSIX::_exit(4)
				if ($_[0] ne 'example.test' ||
				    $_[1]->[0] ne '127.0.0.1');
			return 'mailbox-address-blocked';
			};
		local *get_download_address_callback = sub {
			POSIX::_exit(3)
				if ($_[0] ne 'listed' || $_[1] ne '10.0.0.0/8');
			return $address_checker;
			};
		local *error = sub {
			POSIX::_exit($_[0] eq 'mailbox-address-blocked' ? 0 : 1);
			};
		local *html_escape = sub { return $_[0]; };
		local *http_download = sub {
			my $callback = $_[5];
			POSIX::_exit(5) if (ref($callback) ne 'CODE');
			&$callback(7, '127.0.0.1');
			POSIX::_exit(2);
			};
		xhr();
		POSIX::_exit(6);
		}
	waitpid($pid, 0);
	is($? >> 8, 0, 'XHR checks mode 7 through the existing callback');
	};

done_testing();
