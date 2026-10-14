#!/usr/bin/perl
# Check symlink resolution and cycle detection using isolated filesystem fixtures.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;
my $root = abs_path(tempdir(CLEANUP => 1));

# resolve_counted(path)
# Returns the resolved path and call count, stopping runaway test recursion.
sub resolve_counted
{
my ($path) = @_;
my $original = \&main::resolve_links;
my $calls = 0;
no warnings 'redefine';
local *main::resolve_links = sub {
	# A broken loop guard must fail the test before it can exhaust memory.
	die "Symlink resolution exceeded 100 calls\n" if (++$calls > 100);
	return $original->(@_);
	};
my $resolved = main::resolve_links($path);
return ($resolved, $calls);
}

# Ordinary files, missing targets, and directory links keep their path spelling.
make_path("$root/data", "$root/real/sub");
foreach my $file ("$root/data/file", "$root/real/x", "$root/target") {
	open(my $fh, '>', $file) or die "create $file: $!";
	close($fh) or die "close $file: $!";
	}
foreach my $link (
	[ 'relative', 'data/file' ], [ 'absolute', "$root/data/file" ],
	[ 'dangling', 'missing' ], [ 'alias', 'data' ],
	[ 'dir', 'real/sub' ], [ 'x', 'dir/../x' ]) {
	symlink($link->[1], "$root/$link->[0]") or die "symlink: $!";
	}
foreach my $case (
	[ 'data/file', 'data/file' ], [ 'relative', 'data/file' ],
	[ 'absolute', 'data/file' ], [ 'dangling', 'missing' ],
	[ 'alias/file', 'data/file' ], [ 'alias/./file', 'data/./file' ]) {
	my ($resolved) = resolve_counted("$root/$case->[0]");
	is($resolved, "$root/$case->[1]", "resolves $case->[0]");
	}

# The directory link must be expanded before the following .. is interpreted.
my ($resolved) = resolve_counted("$root/x");
is($resolved, "$root/real/sub/../x",
	'resolves a valid link whose simplified spelling repeats');
is(main::simplify_path($resolved), "$root/real/x",
	'callers can simplify the fully resolved path');

# An absolute target beyond .. must also remain visible to directory checks.
unlink("$root/real/x") or die "unlink: $!";
symlink("$root/target", "$root/real/x") or die "symlink: $!";
($resolved) = resolve_counted("$root/x");
is($resolved, "$root/target", 'follows the final absolute link after ..');
ok(main::is_under_directory($root, "$root/x"),
	'the valid target is still recognized as inside its directory');

# Revisiting a directory link with a shorter remaining path is not a cycle.
($resolved) = resolve_counted("$root/alias/../alias/file");
is($resolved, "$root/data/../data/file",
	'resolves repeated uses of the same directory link');

# Chains longer than common kernel limits remain supported.
foreach my $i (0..44) {
	my $target = $i == 44 ? 'target' : 'chain'.($i+1);
	symlink($target, "$root/chain$i") or die "symlink: $!";
	}
($resolved) = resolve_counted("$root/chain0");
is($resolved, "$root/target", 'resolves a 45-link chain');

# Equivalent loop spellings must still stop after only a few expansions.
foreach my $link (
	[ 'self', 'self' ], [ 'dotself', './dotself' ],
	[ 'parentself', '../'.basename($root).'/parentself' ],
	[ 'a', 'b' ], [ 'b', 'a' ],
	[ 'absa', "$root/absb" ], [ 'absb', "$root/absa" ],
	[ 'absolute-self', "$root/absolute-self" ],
	[ 'via-dir', 'here/via-dir' ], [ 'here', '.' ]) {
	symlink($link->[1], "$root/$link->[0]") or die "symlink: $!";
	}
foreach my $name (qw(self dotself parentself a absa absolute-self via-dir)) {
	my ($loop, $calls) = resolve_counted("$root/$name");
	ok(-l $loop, "$name returns an unresolved loop path");
	cmp_ok($calls, '<=', 4, "$name stops promptly");
	}

# Growing cycles never repeat a full path, but must still stop expanding.
foreach my $link (
	[ 'grow', 'grow/child' ],
	[ 'absolute-grow', "$root/absolute-grow/child" ]) {
	symlink($link->[1], "$root/$link->[0]") or die "symlink: $!";
	my $loop = eval { (resolve_counted("$root/$link->[0]"))[0] };
	is($@, '', "$link->[0] stops before the test recursion guard");
	like($loop || '', qr/^\Q$root\/$link->[0]\E(?:\/child)+$/,
		"$link->[0] returns the unresolved path");
	}

done_testing();
