#!/usr/bin/perl
# Exercise temporary writes and locks through real symlinks in a scratch directory.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

# Keep Webmin configuration and external commands out of these filesystem tests.
no warnings qw(redefine once);
local %main::gconfig = ();
local *main::get_module_acl = sub { return (); };
local *main::is_readonly_mode = sub { return 0; };
local *main::translate_filename = sub { return $_[0]; };
local *main::can_lock_file = sub { return 1; };
local *main::get_lock_links_dir = sub { return undef; };
local *main::has_command = sub { return undef; };
local *main::is_selinux_enabled = sub { return 0; };
local *main::error = sub { die join(' ', @_)."\n"; };

foreach my $opener (qw(open_tempfile open_lock_tempfile)) {
	foreach my $kind (qw(self absolute-self chain dangling)) {
		subtest "$opener through $kind" => sub {
			my $root = abs_path(tempdir(CLEANUP => 1));
			my $file = "$root/link";
			my $target = $file;
			if ($kind eq 'self' || $kind eq 'absolute-self') {
				# Cyclic links must not trap the opener in repeated resolution.
				symlink($kind eq 'self' ? 'link' : $file, $file)
					or die "symlink: $!";
				}
			else {
				# A valid chain must write and lock its final target.
				$target = "$root/target";
				symlink('next', $file) or die "symlink: $!";
				symlink('target', "$root/next") or die "symlink: $!";
				if ($kind eq 'chain') {
					# Cover replacement as well as creation of a missing target.
					open(my $fh, '>', $target) or die "create: $!";
					print $fh "old\n";
					close($fh) or die "close: $!";
					}
				}

			# A regression should fail promptly instead of hanging the suite.
			my $opened;
			my $completed = eval {
				local $SIG{ALRM} = sub { die "Timed out opening symlink\n"; };
				alarm(3);
				$opened = main->can($opener)->('main::TESTFILE', ">$file", 1);
				alarm(0);
				1;
				};
			my $err = $@;
			alarm(0);
			ok($completed, 'opener returns without looping') or diag($err);
			ok($opened, 'opens a temporary file');
			return if (!$opened);

			# Complete the write and verify real lock creation and removal.
			if ($opener eq 'open_lock_tempfile') {
				ok(-f "$target.lock", 'locks the write target');
				}
			main::print_tempfile('main::TESTFILE', "updated\n");
			ok(main::close_tempfile('main::TESTFILE'), 'commits the write');
			open(my $read, '<', $target) or die "read: $!";
			is(<$read>, "updated\n", 'writes the intended target');
			close($read) or die "close: $!";
			ok(!-e "$target.lock", 'leaves no lock file');
			if ($kind eq 'chain' || $kind eq 'dangling') {
				# Following a valid chain must not replace either symlink.
				is(readlink($file), 'next', 'preserves the first link');
				is(readlink("$root/next"), 'target', 'preserves the second link');
				}
			};
		}
	}

done_testing();
