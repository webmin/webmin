#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $bindir = dirname(__FILE__);
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";
my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
my $remote_user = getpwuid($<) || 'root';

sub write_text
{
my ($file, $text) = @_;
open(my $fh, ">", $file) or die "write $file: $!";
print $fh $text;
close($fh) or die "close $file: $!";
}

write_text("$confdir/config", "os_type=generic-linux\nos_version=0\n");
write_text("$confdir/var-path", "$vardir\n");
write_text("$confdir/miniserv.conf",
	   "root=$rootdir\nuserfile=$confdir/miniserv.users\n");
write_text("$confdir/miniserv.users", "");
make_path("$confdir/useradmin");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'MINISERV_CONFIG'} = "$confdir/miniserv.conf";
$ENV{'FOREIGN_MODULE_NAME'} = 'useradmin';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;
$ENV{'REMOTE_USER'} = $remote_user;
$ENV{'BASE_REMOTE_USER'} = $remote_user;

chdir("$rootdir/useradmin") or die "chdir useradmin: $!";
require "$rootdir/useradmin/user-lib.pl";

our %access;

sub clear_acl_cache
{
no warnings 'once';
undef(%main::read_file_cache);
undef(%main::read_file_missing);
undef(%main::read_file_cache_time);
}

sub write_global_acl
{
write_acl_for($remote_user, @_);
}

sub write_acl_for
{
my ($user, %opts) = @_;
my $text = "";
foreach my $k (sort keys %opts) {
	$text .= "$k=$opts{$k}\n";
	}
write_text("$confdir/$user.acl", $text);
clear_acl_cache();
}

my $tmp = tempdir(CLEANUP => 1);
my $allowed = "$tmp/allowed";
my $other = "$tmp/other";
my $outside = "$tmp/outside";
make_path($allowed, $other, $outside);
write_text("$allowed/batch.txt", "batch\n");
write_text("$other/also-batch.txt", "other\n");
write_text("$outside/secret.txt", "secret\n");

write_global_acl(
	root => $allowed,
	otherdirs => $other,
	fileunix => $remote_user,
	);

subtest 'server-side user export grants' => sub {
	my %acl = ( 'export' => 2, 'uedit_mode' => 2, 'home' => abs_path($allowed) );
	ok(can_export_users_to_file(\%acl), 'named users can be exported in a granted directory');
	my $path = abs_path($allowed)."/export.txt";
	write_delegated_export($acl{'home'}, $path, [ "first\n" ]);
	write_delegated_export($acl{'home'}, $path, [ "second\n" ]);
	is(read_file_contents($path), "second\n", 'a second export replaces the first');
	is((stat($path))[2] & 0777, 0600, 'exported account details stay private');
	{
		no warnings qw(redefine once);
		local *main::error = sub { die join('', @_)."\n" };
		my $outside = abs_path($other)."/export.txt";
		ok(!eval { write_delegated_export($acl{'home'}, $outside, [ 'row' ]); 1 },
		   'the writer checks the actual destination directory');
		ok(!-e $outside, 'nothing is written outside the directory grant');
		}
	for my $home ('', '/', '/./') {
		local $acl{'home'} = $home;
		ok(!can_export_users_to_file(\%acl), 'delegated export needs a bounded directory');
		}
	local $acl{'uedit_mode'} = 0;
	local $acl{'home'} = '/';
	ok(can_export_users_to_file(\%acl), 'full administrator keeps unrestricted export');
	local $acl{'export'} = 1;
	ok(!can_export_users_to_file(\%acl), 'browser-only export cannot write a file');
	};

subtest 'local batch file path ACLs' => sub {
	%access = ( 'batchdir' => $allowed );
	ok(can_read_batch_local_file("$allowed/batch.txt"),
	   'file under batchdir and global root is allowed');
	ok(!can_read_batch_local_file("$other/also-batch.txt"),
	   'global otherdirs alone cannot bypass narrower batchdir');
	ok(!can_read_batch_local_file("$outside/secret.txt"),
	   'outside file is rejected');
	ok(!can_read_batch_local_file("relative/batch.txt"),
	   'relative paths are rejected');
	ok(!can_read_batch_local_file(undef),
	   'missing local file path is rejected');

	%access = ( 'batchdir' => "" );
	ok(!can_read_batch_local_file("$allowed/batch.txt"),
	   'blank batchdir denies local server files');

	%access = ( );
	ok(can_read_batch_local_file("$allowed/batch.txt"),
	   'missing batchdir falls back to / for old ACL compatibility');

	%access = ( 'batchdir' => $tmp );
	ok(can_read_batch_local_file("$other/also-batch.txt"),
	   'batchdir plus global otherdirs allows second configured tree');
	};

SKIP: {
	skip('symlinks are unavailable', 1)
		if !symlink("$outside/secret.txt", "$allowed/link.txt");
	%access = ( 'batchdir' => $allowed );
	ok(!can_read_batch_local_file("$allowed/link.txt"),
	   'symlink escaping batchdir/global root is rejected');
	}

%access = ( 'batchdir' => $allowed );
is(read_batch_local_file("$allowed/batch.txt"), "batch\n",
   'allowed batch file is read');

subtest 'global ACL file read and copy helpers' => sub {
	my $copy = "$tmp/copied-batch.txt";
	ok(copy_file_under_global_acl("$allowed/batch.txt", $copy),
	   'allowed file can be copied through global ACL helper');
	is(read_file_contents($copy), "batch\n",
	   'copied file has expected contents');

	my $modecopy = "$tmp/mode-preserving-copy.txt";
	write_text($modecopy, "old\n");
	chmod(0644, "$allowed/batch.txt");
	chmod(0600, $modecopy);
	ok(copy_source_dest("$allowed/batch.txt", $modecopy, 1, 1),
	   'contents-only copy succeeds');
	is((stat($modecopy))[2] & 0777, 0600,
	   'contents-only copy retains destination permissions');

	my $blocked = "$tmp/blocked-copy.txt";
	ok(!copy_file_under_global_acl("$outside/secret.txt", $blocked),
	   'outside file cannot be copied through global ACL helper');
	ok(!-e $blocked, 'blocked copy does not create destination');
	};

subtest 'global ACL home fallback for Webmin-only users' => sub {
	my $webmin_only = "webmin-batch-no-such-user-$$";
	no warnings 'once';
	local $main::remote_user = $webmin_only;
	local $main::base_remote_user = $webmin_only;
	local $WebminCore::remote_user = $webmin_only;
	local $WebminCore::base_remote_user = $webmin_only;

	write_acl_for(
		$webmin_only,
		root => "",
		otherdirs => "",
		fileunix => "nobody",
		);
	%access = ( 'batchdir' => "/" );
	ok(!can_read_batch_local_file("$outside/secret.txt"),
	   'missing Unix home does not fall back to filesystem root');

	write_acl_for(
		$webmin_only,
		root => "~/allowed",
		otherdirs => "",
		fileunix => "nobody",
		);
	ok(!can_read_batch_local_file("/allowed/batch.txt"),
	   'home-relative root does not become an absolute path without a home');

	write_acl_for(
		$webmin_only,
		root => "",
		otherdirs => $allowed,
		fileunix => "nobody",
		);
	ok(can_read_batch_local_file("$allowed/batch.txt"),
	   'explicit otherdirs still permits configured paths');
	};

# Admins limited to some users must not take over other users' identities,
# home directories or files.
subtest 'restricted admin UID and home helpers' => sub {
	my %full = ( 'uedit_mode' => 0, 'home' => '/' );
	my %named = ( 'uedit_mode' => 2, 'uedit' => 'alice bob',
		      'home' => $tmp );
	my @users = (
		{ 'user' => 'alice', 'uid' => 50001, 'home' => "$tmp/a" },
		{ 'user' => 'bob', 'uid' => 50002, 'home' => "$tmp/b" },
		{ 'user' => 'carol', 'uid' => 50003, 'home' => "$tmp/c" },
		{ 'user' => 'root', 'uid' => 0, 'home' => '/root' } );
	ok(!restricted_user_acl(\%full), 'all-user admins are unrestricted');
	ok(restricted_user_acl(\%named), 'name-limited admins are restricted');

	# UIDs of uneditable users, including root, are refused
	like(check_user_uid_owner(\%named, 0, 'alice', \@users), qr/UID 0/,
	     'root UID is refused for a name-limited admin');
	ok(check_user_uid_owner(\%named, 50003, 'alice', \@users),
	   'UID of an uneditable user is refused');
	ok(!check_user_uid_owner(\%named, 50002, 'alice', \@users),
	   'UID of an editable user is allowed');
	ok(!check_user_uid_owner(\%named, 50001, 'alice', \@users),
	   'own UID is allowed');
	ok(!check_user_uid_owner(\%named, 59999, 'alice', \@users),
	   'unused UID is allowed');
	ok(!check_user_uid_owner(\%full, 0, 'alice', \@users),
	   'unrestricted admins keep full UID choice');

	# The home base and other users' homes are refused
	for my $home ($tmp, "$tmp/", "$tmp/./") {
		ok(check_user_home(\%named, $home, undef, 'alice', \@users),
		   "home base $home is refused");
		}
	{
		no warnings 'once';
		local $main::config{'home_base'} = "$tmp/homes";
		ok(check_user_home(\%named, "$tmp/homes", undef, 'alice',
				   \@users),
		   'configured home base is refused');
	}
	ok(check_user_home(\%named, "$tmp/c", "$tmp/a", 'alice', \@users),
	   'another user home is refused');
	ok(check_user_home(\%named, "$tmp/c/", undef, 'dave', \@users),
	   'another user home with a trailing slash is refused');
	ok(!check_user_home(\%named, "$tmp/a", "$tmp/a", 'alice', \@users),
	   'unchanged home is accepted');
	ok(!check_user_home(\%named, "$tmp/nested/alice", undef, 'alice',
			    \@users),
	   'new home below the base is accepted');
	ok(!check_user_home(\%full, '/', undef, 'alice', \@users),
	   'unrestricted admins keep full home choice');

	# Existing directories are only changed when owned by the user
	my $owned = "$tmp/owned";
	make_path($owned);
	my $uid = (stat($owned))[4];
	ok(can_change_home_directory(\%named,
		{ 'uid' => $uid, 'home' => $owned }),
	   'own directory can be changed');
	ok(!can_change_home_directory(\%named,
		{ 'uid' => $uid + 1, 'home' => $owned }),
	   'directory owned by another UID is protected');
	ok(can_change_home_directory(\%named,
		{ 'uid' => $uid + 1, 'home' => "$tmp/missing" }),
	   'missing directory can be created');
	ok(can_change_home_directory(\%full,
		{ 'uid' => $uid + 1, 'home' => $owned }),
	   'unrestricted admins keep existing behaviour');
	};

done_testing();
