#!/usr/bin/perl
# Check that open_beneath opens and creates entries below a base directory
# without following links at any level.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use Cwd qw(getcwd);
use Fcntl qw(O_WRONLY O_CREAT O_EXCL O_TRUNC);
use constant O_DIRECTORY => eval { Fcntl::O_DIRECTORY() };
use File::Temp qw(tempdir);
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";

unless (O_DIRECTORY && eval { Fcntl::O_NOFOLLOW() }) {
	ok(!open_beneath('/', '/unused') && $!{EINVAL},
	   'refuses to open paths when the required flags are unavailable');
	done_testing();
	exit;
}

# Keep the test independent of the host's Webmin configuration.
my $readonly = 0;
*main::is_readonly_mode = sub { return $readonly; };
*main::error = sub { die join('', @_)."\n"; };

my $tmp = Cwd::abs_path(tempdir(TMPDIR => 1, CLEANUP => 1));
my ($base, $outside) = ("$tmp/base", "$tmp/outside");
mkdir($_) || die $! foreach ($base, "$base/sub", $outside);
open(my $out, '>', "$base/sub/file") || die $!;
print $out "inside\n";
close($out);
open($out, '>', "$outside/secret") || die $!;
close($out);
my $cwd = getcwd();

# Existing entries open through real directories.
my $fh = open_beneath($base, "$base/sub/file");
is($fh && scalar(<$fh>), "inside\n", 'opens an existing file');
ok(-d open_beneath("$base/", "$base//sub", O_DIRECTORY),
   'opens an existing directory');
ok(open_beneath("/", "$base/sub/file"), 'opens below a base of /');

# New files and directories are created where the path says.
$fh = open_beneath($base, "$base/sub/new", O_WRONLY | O_CREAT | O_EXCL, 0600);
ok($fh && (print $fh "x") && close($fh), 'creates a new file');
is((stat("$base/sub/new"))[2] & 07777, 0600, 'new file has its permissions');
ok(!open_beneath($base, "$base/sub/new", O_WRONLY | O_CREAT | O_EXCL, 0600) &&
   $!{EEXIST}, 'refuses to create a file that exists');
$fh = open_beneath($base, "$base/sub/dir", O_DIRECTORY | O_CREAT | O_EXCL,
		   0700);
ok($fh && -d $fh, 'creates a new directory');
is((stat("$base/sub/dir"))[2] & 07777, 0700,
   'new directory has its permissions');
ok(!open_beneath($base, "$base/sub/dir", O_DIRECTORY | O_CREAT | O_EXCL) &&
   $!{EEXIST}, 'refuses to create a directory that exists');
ok(open_beneath($base, "$base/sub/dir", O_DIRECTORY | O_CREAT),
   'opens an existing directory when creation is optional');

# A link is refused as the last part and as a directory on the way.
symlink("$outside/secret", "$base/sub/filelink") || die $!;
symlink($outside, "$base/dirlink") || die $!;
symlink("$outside/made", "$base/sub/dangling") || die $!;
ok(!open_beneath($base, "$base/sub/filelink"), 'refuses a link to a file');
ok(!open_beneath($base, "$base/dirlink", O_DIRECTORY),
   'refuses a link to a directory');
ok(!open_beneath($base, "$base/dirlink/secret"),
   'refuses a link on the way to a file');
ok(!open_beneath($base, "$base/dirlink/made", O_WRONLY | O_CREAT, 0600) &&
   !-e "$outside/made", 'does not create a file through a link on the way');
ok(!open_beneath($base, "$base/dirlink/made", O_DIRECTORY | O_CREAT, 0700) &&
   !-e "$outside/made", 'does not create a directory through a link');
ok(!open_beneath($base, "$base/sub/dangling", O_WRONLY | O_CREAT, 0600) &&
   !-e "$outside/made", 'does not create a file through a dangling link');

# A path ending in a slash must be a directory.
ok(-d open_beneath($base, "$base/sub/"),
   'opens a directory named with a slash');
ok(!open_beneath($base, "$base/sub/file/") &&
   !open_beneath($base, "$base/sub/file/."),
   'refuses a file named with a slash');
ok(!open_beneath($base, "$base/sub/slash/", O_WRONLY | O_CREAT, 0600) &&
   !-e "$base/sub/slash", 'creates nothing for a writable path with a slash');
ok(!open_beneath($base, "$base/sub/slash/.", O_CREAT | O_EXCL, 0600) &&
   !-e "$base/sub/slash", 'a trailing /. does not request directory creation');
ok(!open_beneath($base, "$base/sub/trunc", O_DIRECTORY | O_CREAT | O_TRUNC) &&
   !-e "$base/sub/trunc", 'refuses truncation before creating a directory');
ok(open_beneath($base, "$base/sub/\n", O_WRONLY | O_CREAT | O_EXCL, 0600),
   'a newline can be the last filename component');

# A timeout during an open must not leave the caller in another directory.
POSIX::mkfifo("$base/sub/fifo", 0600) || die $!;
eval {
	local $SIG{ALRM} = sub { die "timeout\n" };
	alarm(1);
	open_beneath($base, "$base/sub/fifo");
	};
alarm(0);
is($@, "timeout\n", 'a timeout during an open reaches the caller');
is(getcwd(), $cwd, 'working directory is restored after a timeout');
chdir($cwd);

# Paths that could leave the base are rejected before anything is opened.
ok(!open_beneath($base, "$base/sub/../../outside/secret"),
   'refuses a path with .. parts');
ok(!open_beneath($base, "$outside/secret"), 'refuses a path outside the base');
ok(!open_beneath($base, $base), 'refuses the base itself');
ok(!open_beneath("", "$base/sub/file"), 'refuses an empty base');
chdir($tmp) || die $!;
ok(!open_beneath("base", "base/sub/file"), 'refuses a relative base');
chdir($cwd) || die $!;

# Read-only mode blocks changes but not reads.
$readonly = 1;
ok(!open_beneath($base, "$base/sub/blocked", O_WRONLY | O_CREAT, 0600) &&
   !-e "$base/sub/blocked", 'creates nothing in read-only mode');
ok(open_beneath($base, "$base/sub/file"), 'still reads in read-only mode');

is(getcwd(), $cwd, 'working directory is unchanged');
done_testing();
