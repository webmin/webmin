#!/usr/bin/perl
# Check that message deletes report failures and never follow symlinks.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/../..");
my $tmp = tempdir(CLEANUP => 1);
our ($root_directory, $config_directory, $var_directory,
     $module_config_directory, $user_module_config_directory,
     $module_var_directory, $done_web_lib_funcs, $error_must_die,
     %config, %gconfig, %access, $null_file, $remote_user);
$root_directory = $root;
$config_directory = "$tmp/config";
$var_directory = "$tmp/var";
$module_config_directory = $user_module_config_directory = "$tmp/config/mailbox";
$module_var_directory = "$tmp/var/mailbox";
make_path($module_config_directory, $module_var_directory);
$error_must_die = 1;
$null_file = "/dev/null";
%config = (noindex_hostname => 1);
%gconfig = (product => 'usermin');
require "$root/web-lib-funcs.pl";
$done_web_lib_funcs = 1;
require "$root/web-lib.pl";
require "$root/mailboxes/boxes-lib.pl";
require "$root/mailboxes/folders-lib.pl";

# Permission checks do not apply to root, so failure cases need another user
my $nonroot = $< != 0 && $> != 0;

# message(path) writes a small message fixture
sub message
{
my ($path) = @_;
open(my $fh, '>', $path) or die "$path: $!";
print $fh "From: a\@example.test\nSubject: test\n\nbody\n";
close($fh) or die "$path: $!";
}

# slurp(path) returns the contents of a file
sub slurp
{
my ($path) = @_;
open(my $fh, '<', $path) or die "$path: $!";
local $/;
return scalar(<$fh>);
}

# maildir(name, count) creates a Maildir with some messages in cur
sub maildir
{
my ($name, $count) = @_;
my $dir = "$tmp/$name";
make_path(map { "$dir/$_" } qw(cur new tmp));
message("$dir/cur/msg$_:2,") for (1..$count);
return $dir;
}

subtest 'Maildir deletes succeed and ignore messages already gone' => sub {
	my $dir = maildir('ok', 2);
	my @mails = ( { 'file' => "$dir/cur/msg1:2," },
		      { 'file' => "$dir/cur/gone:2," } );
	ok(eval { delete_maildir(@mails); 1 }, 'no error') or diag($@);
	ok(!-e "$dir/cur/msg1:2,", 'message deleted');
	ok(-e "$dir/cur/msg2:2,", 'other message kept');
	ok(eval { empty_maildir($dir); 1 }, 'empty succeeds') or diag($@);
	ok(!-e "$dir/cur/msg2:2,", 'folder emptied');
	};

SKIP: {
	skip 'permission failures cannot be tested as root', 3 if (!$nonroot);

	subtest 'Maildir delete failures are reported' => sub {
		my $dir = maildir('ro', 2);
		chmod(0555, "$dir/cur") or die $!;
		my $ok = eval { delete_maildir({ 'file' => "$dir/cur/msg1:2," });
				1 };
		ok(!$ok, 'delete_maildir fails');
		like($@, qr/Failed to delete 1 message files : .*msg1/,
		     'error names the message');
		$ok = eval { empty_maildir($dir); 1 };
		ok(!$ok, 'empty_maildir fails');
		like($@, qr/Failed to delete 2 message files/, 'count reported');
		chmod(0755, "$dir/cur");
		};

	subtest 'MH delete failures are reported' => sub {
		my $dir = "$tmp/mh";
		make_path($dir);
		message("$dir/$_") for (1..2);
		chmod(0555, $dir) or die $!;
		my $ok = eval { delete_mhdir({ 'file' => "$dir/1" }); 1 };
		ok(!$ok, 'delete_mhdir fails');
		like($@, qr/Failed to delete .*\/1/, 'error names the message');
		$ok = eval { empty_mhdir($dir); 1 };
		ok(!$ok, 'empty_mhdir fails');
		chmod(0755, $dir);
		ok(eval { delete_mhdir({ 'file' => "$dir/1" },
				       { 'file' => "$dir/9" }); 1 },
		   'writable MH delete ignores a missing message') or diag($@);
		ok(!-e "$dir/1" && -e "$dir/2", 'only the chosen message deleted');
		};

	subtest 'a failed modify keeps the original message' => sub {
		my $dir = maildir('modify', 1);
		chmod(0555, "$dir/cur") or die $!;
		my $file = "$dir/cur/msg1:2,";
		my $ok = eval { modify_maildir({ 'file' => $file },
			{ 'headers' => [ [ 'Subject', 'new' ] ],
			  'body' => "new\n" }, 1); 1 };
		ok(!$ok, 'modify_maildir fails');
		like($@, qr/Failed to delete/, 'error reported');
		ok(-s $file, 'original message kept');
		chmod(0755, "$dir/cur");
		};
	}

subtest 'temp files for a mail user are never opened through symlinks' => sub {
	# Act as if root is writing for a mail user, without changing IDs
	local *main::should_switch_to_mail_user = sub { 1 };
	local *main::switch_to_mail_user = sub { 0 };
	local *main::get_switch_user_info = sub { getpwuid($<) };
	my $dir = "$tmp/create";
	make_path($dir);
	my $target = "$tmp/protected";
	message($target);
	my $before = slurp($target);
	symlink($target, "$dir/sent.del") or die $!;

	ok(create_as_mail_user('DEST',">$dir/sent.del"), 'temp file created');
	print DEST "temp\n";
	close(DEST);
	ok(!-l "$dir/sent.del", 'symlink replaced by a regular file');
	is(slurp($target), $before, 'symlink target unchanged');

	# A stale regular file left by an earlier run is replaced too
	ok(create_as_mail_user('DEST',">$dir/sent.del"), 'stale file replaced');
	close(DEST);
	is(-s "$dir/sent.del", 0, 'new temp file starts empty');
	};

subtest 'mbox deletes still work with a stale temp file' => sub {
	my $file = "$tmp/mbox/inbox";
	make_path("$tmp/mbox");
	open(my $fh, '>', $file) or die $!;
	foreach my $i (1..2) {
		print $fh "From a\@example.test Tue Oct 27 12:00:00 2026\n",
			  "From: a\@example.test\nSubject: mbox$i\n\nbody$i\n\n";
		}
	close($fh);
	open($fh, '>', "$user_module_config_directory/inbox.del") or die $!;
	print $fh "stale\n";
	close($fh);
	my $folder = { 'type' => 0, 'file' => $file };
	my @mails = mailbox_list_mails(0, 1, $folder);
	ok(eval { mailbox_delete_mail($folder, $mails[0]); 1 }, 'delete works')
		or diag($@);
	my $left = slurp($file);
	unlike($left, qr/mbox1/, 'chosen message removed');
	like($left, qr/mbox2/, 'other message kept');
	};

subtest 'temp files without a mail user are never opened through symlinks' => sub {
	my $dir = "$tmp/create-plain";
	make_path($dir);
	my $target = "$tmp/protected-plain";
	message($target);
	my $before = slurp($target);
	symlink($target, "$dir/inbox.del") or die $!;
	ok(create_as_mail_user('DEST', ">$dir/inbox.del"), 'temp file created');
	print DEST "temp\n";
	close(DEST);
	ok(!-l "$dir/inbox.del", 'symlink replaced by a regular file');
	is(slurp($target), $before, 'symlink target unchanged');
	};

SKIP: {
	skip 'root-owned folder cases need root', 2 if ($nonroot);

	subtest 'root deletes only from real root-owned directories' => sub {
		my $dir = maildir('rootdir', 1);
		ok(unlink_in_root_dir("$dir/cur", "msg1:2,"), 'deleted as root');
		my $other = "$tmp/victim";
		make_path($other);
		message("$other/file");
		symlink($other, "$dir/link") or die $!;
		ok(!unlink_in_root_dir("$dir/link", "file"), 'symlink refused');
		ok(-e "$other/file", 'file behind the symlink kept');
		};

	subtest 'mail user falls back to root only for root-owned folders' => sub {
		my $dir = maildir('fallback', 1);
		chmod(0555, "$dir/cur") or die $!;
		my $user = getpwnam('nobody') ? 'nobody' : undef;
		plan skip_all => 'no nobody user' if (!$user);
		local $main::mail_open_user = $user;
		ok(unlink_mail_file("$dir/cur/msg1:2,"), 'root fallback deleted it');
		};
	}

done_testing();
