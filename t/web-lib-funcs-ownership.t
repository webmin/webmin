#!/usr/bin/perl
# Exercise set_ownership_permissions_recursive on temporary trees with links
# that point outside them.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(getcwd realpath);
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";
require "$FindBin::Bin/test-lib.pl";

# Avoid loading workstation configuration or writing Webmin debug logs.
local %main::gconfig = ();
local $main::readonly_mode_cache = 0;
local @main::filename_callbacks = ();
umask(022);
my $root = realpath(tempdir(CLEANUP => 1));
my $start = getcwd();

# Root hands the tree to nobody. Other users can only keep their own uid.
my ($uid, $gid) = ($<, (split(' ', $())[0]);
if ($< == 0 && defined(getpwnam('nobody'))) {
    ($uid, $gid) = (getpwnam('nobody'))[2, 3];
}

# build_tree(name): create a tree with nested directories and links that point
# outside it. Returns the base holding the tree and the link targets.
sub build_tree
{
my ($name) = @_;
my $base = "$root/$name";
mkdir($_, 0755) or die "mkdir $_: $!"
    foreach ($base, "$base/outside", "$base/outside/dir", "$base/tree",
             "$base/tree/a", "$base/tree/a/b", "$base/tree/empty");
write_text("$base/outside/secret", "secret\n");
write_text("$base/outside/dir/inner", "inner\n");
write_text("$base/tree/top", "top\n");
write_text("$base/tree/a/b/deep", "deep\n");
chmod(0600, "$base/outside/secret", "$base/outside/dir/inner");
symlink("../../outside/secret", "$base/tree/a/secret") or die $!;
symlink("$base/outside/dir", "$base/tree/a/dir") or die $!;
symlink("$base/missing", "$base/tree/dangling") or die $!;
symlink("$base/outside/dir", "$base/toplink") or die $!;
return $base;
}

# state_of(path, ...): owner, group and mode of each path, links not followed.
sub state_of
{
return join(" ", map { my @st = lstat($_);
                       "$st[4]:$st[5]:".sprintf("%o", $st[2] & 07777) } @_);
}

# outside_of(base): the state of every link target outside the tree.
sub outside_of
{
my ($base) = @_;
return state_of("$base/outside/secret", "$base/outside/dir",
                "$base/outside/dir/inner");
}

# A whole tree gets the owner and mode, and links are left alone.
my $base = build_tree('basic');
my $outside = outside_of($base);
my $links = state_of(map { "$base/tree/$_" } ('a/secret', 'a/dir', 'dangling'));
ok(main::set_ownership_permissions_recursive($uid, $gid, 0750, "$base/tree"),
   'tree: every change succeeds');
is(getcwd(), $start, 'tree: current directory restored');
is(state_of(map { "$base/tree$_" } ('', '/a', '/a/b', '/empty', '/top',
                                    '/a/b/deep')),
   join(" ", ("$uid:$gid:750") x 6), 'tree: files and directories changed');
is(state_of(map { "$base/tree/$_" } ('a/secret', 'a/dir', 'dangling')), $links,
   'tree: links skipped');
is(outside_of($base), $outside, 'tree: link targets untouched');

# A link given directly is skipped too.
ok(main::set_ownership_permissions_recursive($uid, $gid, 0700,
                                             "$base/toplink"),
   'top link: call succeeds');
is(outside_of($base), $outside, 'top link: target untouched');

# Relative names resolve from the caller's directory.
$base = build_tree('relative');
chdir($base) or die $!;
ok(main::set_ownership_permissions_recursive(undef, undef, 0700,
                                             'tree/a', 'tree/top'),
   'relative: changes succeed');
is(getcwd(), $base, 'relative: current directory restored');
is(join(" ", map { sprintf("%o", (lstat("$base/tree$_"))[2] & 07777) }
                 ('/a', '/a/b/deep', '/top', '', '/empty')),
   '700 700 700 755 755', 'relative: only the named entries changed');
chdir($start) or die $!;

# In list context, a failure names the file and the reason.
$base = build_tree('error');
{
    require Errno;
    my $real = \&main::set_ownership_permissions;
    no warnings 'redefine';
    local *main::set_ownership_permissions = sub {
        return $real->(@_) if ($_[3] ne 'deep');
        $! = Errno::EACCES();
        return 0;
    };
    my ($ok, $err) = main::set_ownership_permissions_recursive(
        undef, undef, 0700, "$base/tree");
    ok(!$ok, 'error: failure reported');
    like($err, qr{^\Q$base/tree/a/b/deep\E : \S}, 'error: file and reason');
    is(sprintf("%o", (lstat("$base/tree/top"))[2] & 07777), '700',
       'error: other files still changed');
    ($ok, $err) = main::set_ownership_permissions_recursive(
        undef, undef, 0700, "$base/tree/top");
    ok($ok && !defined($err), 'error: none after success');
}

# Read-only mode leaves the tree alone.
$base = build_tree('readonly');
{
    local $main::readonly_mode_cache = 1;
    local *STDERR;
    open(STDERR, '>', '/dev/null');
    ok(main::set_ownership_permissions_recursive($uid, $gid, 0700,
                                                 "$base/tree"),
       'read-only: call reports success');
}
is(sprintf("%o", (lstat("$base/tree/top"))[2] & 07777), '644',
   'read-only: nothing changed');
done_testing();
