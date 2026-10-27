#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

# Inject delivery immediately before a real rename without replacing its result.
our $before_rename;
BEGIN {
	*CORE::GLOBAL::rename = sub {
		if ($before_rename) {
			my $callback = $before_rename;
			$before_rename = undef;
			$callback->(@_);
			}
		return CORE::rename($_[0], $_[1]);
		};
	}

# An optional source root allows the same cases to run against the original PR.
my $root = abs_path(shift(@ARGV) || dirname(__FILE__)."/../..");
my $tmp = tempdir(CLEANUP => 1);
our ($root_directory, $config_directory, $var_directory,
     $module_config_directory, $user_module_config_directory,
     $module_var_directory, $done_web_lib_funcs, $error_must_die,
     %config, %gconfig, %sorted_ids_cache, $null_file);
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

# message(path, subject) writes a small, complete fixture message.
sub message
{
my ($path, $subject) = @_;
open(my $fh, '>', $path) or die "$path: $!";
print $fh "From: a\@example.test\nTo: b\@example.test\n",
	"Subject: $subject\nMessage-ID: <$subject\@example.test>\n",
	"Date: Tue, 27 Oct 2026 12:00:00 +0000\n\nbody\n";
close($fh) or die "$path: $!";
}

# folder(name, count) creates a separate Maildir with unread messages.
sub folder
{
my ($name, $count) = @_;
my $dir = "$tmp/$name/Maildir";
make_path(map { "$dir/$_" } qw(cur new tmp));
foreach my $i (1..$count) {
	message("$dir/cur/msg$i:2,", "message$i");
	}
my $folder = { type => 1, file => $dir, sortable => 1, flags => 2 };
$folder->{'lastchange'} = modification_time($folder);
return $folder;
}

subtest 'delivery during a flag rename is not hidden' => sub {
	my $folder = folder('delivery', 1);
	my $dir = $folder->{'file'};
	my ($mail) = select_maildir($dir, ['cur/msg1:2,'], 1);
	local $before_rename = sub { message("$dir/new/delivered", 'delivered'); };
	mailbox_set_read_flag($folder, $mail, 1, 0, 0);
	is_deeply([sort(get_maildir_files($dir))],
		  ["$dir/cur/msg1:2,S", "$dir/new/delivered"],
		  'both the renamed message and concurrent delivery are visible');
	};

subtest 'failed rename preserves the mail object and sort index' => sub {
	my $folder = folder('failed-rename', 1);
	my $dir = $folder->{'file'};
	my @before = build_sorted_ids($folder, 'subject', 1);
	my ($mail) = select_maildir($dir, ['cur/msg1:2,'], 1);
	my %original = %$mail;
	# A file cannot replace a directory, even when the test runs as root.
	mkdir("$dir/cur/msg1:2,S") or die $!;
	my $ok = eval { mailbox_set_read_flag($folder, $mail, 1, 0, 0); 1 };
	ok(!$ok, 'failure is reported to the caller');
	like($@, qr/Failed to rename/, 'error identifies the failed operation');
	ok(-f "$dir/cur/msg1:2,", 'original message still exists');
	is_deeply($mail, \%original, 'mail object is unchanged');
	is_deeply([build_sorted_ids($folder, 'subject', 1)], \@before,
		  'sort index retains the original ID');
	my %index;
	open_dbm_db(\%index, folder_new_sort_index_file($folder), 0600);
	ok(defined($index{'cur/msg1:2,_size'}), 'original DBM entry remains');
	ok(!defined($index{'cur/msg1:2,S_size'}), 'no DBM entry for a failed rename');
	dbmclose(%index);
	};

subtest 'bulk flags avoid mailbox-sized work for each message' => sub {
	my $folder = folder('bulk', 100);
	my $dir = $folder->{'file'};
	my @before = build_sorted_ids($folder, 'subject', 1);
	my $ifile = folder_new_sort_index_file($folder);
	my $cachefile = get_maildir_cachefile($dir);
	my @ids = map { "cur/msg$_:2," } 1..20;
	my @mails = select_maildir($dir, \@ids, 1);
	my ($writes, $lists) = (0, 0);
	my $opener = \&open_tempfile;
	my $lister = \&get_maildir_files;
	{
		no warnings 'redefine';
		local *main::open_tempfile = sub {
			$writes++ if (defined($_[1]) &&
				($_[1] eq ">$cachefile" || $_[1] eq ">$ifile.ids"));
			return &$opener(@_);
			};
		local *main::get_maildir_files = sub { $lists++; return &$lister(@_); };
		# Toggle both ways before sorting to check repeated pending renames.
		foreach my $read (1, 0, 1) {
			foreach my $mail (@mails) {
				mailbox_set_read_flag($folder, $mail, $read, 0, 0);
				}
			}
		}
	is($writes, 0, 'batch does not rewrite whole cache files');
	is($lists, 0, 'batch does not fetch the entire file list per message');
	is(scalar(grep { -f "$dir/${_}S" } @ids), 20, 'all flag renames succeeded');
	my %changed = map { $_ => 1 } @ids;
	my @expected = map { $changed{$_} ? $_.'S' : $_ } @before;
	my $reads = 0;
	my $reader = \&read_mail_file;
	{
		no warnings 'redefine';
		local *main::read_mail_file = sub { $reads++; return &$reader(@_); };
		is_deeply([build_sorted_ids($folder, 'subject', 1)], \@expected,
			  'next sort uses the renamed IDs in the same order');
		}
	is($reads, 0, 'renaming preserves the cached message headers');
	ok(-s "$ifile.ids", 'next sort recreates the sidecar');
	my %index;
	open_dbm_db(\%index, $ifile, 0600);
	ok(!$index{'recheck'}, 'refresh is not repeated on later requests');
	dbmclose(%index);
	};

done_testing();
