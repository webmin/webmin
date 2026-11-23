#!/usr/bin/perl
# Checks that edit_action.cgi only shows known init.d and runlevel scripts,
# so start/stop-only users cannot read other files through crafted names.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use IPC::Open3 ();
use Symbol qw(gensym);

my $bindir = abs_path($0);
$bindir =~ s{/[^/]+$}{};
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";
my $tmp = tempdir(CLEANUP => 1);
my $confdir = "$tmp/etc";
my $vardir = "$tmp/var";
my $base = "$tmp/rc";
my $initdir = "$base/init.d";
make_path("$confdir/init", $vardir, $initdir, "$base/rc2.d");

# write_file(path, content)
# Creates a test file with the given content
sub write_file
{
my ($path, $data) = @_;
open(my $fh, ">", $path) or die "$path: $!";
print $fh $data;
close($fh);
}

# Minimal Webmin config for a start/stop-only user of the init module
write_file("$confdir/config", "os_type=generic-linux\nos_version=0\n");
write_file("$confdir/var-path", "$vardir\n");
write_file("$confdir/miniserv.conf", "root=$rootdir\n");
write_file("$confdir/webmin.acl", "root: init\n");
write_file("$confdir/init/config",
	   "init_mode=init\ninit_dir=$initdir\ninit_base=$base\n");
write_file("$confdir/init/root.acl", "bootup=2\nnoconfig=1\n");

# One real action, one runlevel-only script, and a secret file
write_file("$initdir/demo", "#!/bin/sh\necho demo-action-body\n");
write_file("$base/rc2.d/S10local", "#!/bin/sh\necho runlevel-body\n");
write_file("$tmp/secret", "secret-file-body\n");

# run_cgi(args...)
# Runs edit_action.cgi with query-string style arguments, returning output
sub run_cgi
{
my @args = @_;
local %ENV = ( %ENV,
	       WEBMIN_CONFIG => $confdir,
	       WEBMIN_VAR => $vardir,
	       REMOTE_USER => 'root',
	       BASE_REMOTE_USER => 'root',
	       REQUEST_METHOD => 'GET',
	       SERVER_ROOT => $rootdir,
	       SCRIPT_NAME => '/init/edit_action.cgi',
	       QUERY_STRING => join("+", @args) );
my $err = gensym();
my $pid = IPC::Open3::open3(my $in, my $out, $err, $^X,
			    "$rootdir/init/edit_action.cgi", @args);
close($in);
local $/;
my $stdout = <$out> // '';
my $stderr = <$err> // '';
waitpid($pid, 0);
return $stdout.$stderr;
}

chdir("$rootdir/init") or die "chdir: $!";

my $out = run_cgi(0, "$tmp/secret");
unlike($out, qr/secret-file-body/, 'absolute path is not shown');
like($out, qr/not allowed to edit bootup actions/,
     'absolute path is rejected');

$out = run_cgi(1, 2, 's', 'ecret', 0, '../../');
unlike($out, qr/secret-file-body/, 'runlevel traversal is not shown');
like($out, qr/not allowed to edit bootup actions/,
     'runlevel traversal is rejected');

$out = run_cgi(1, 2, '10', 'local', 0, 'K');
like($out, qr/not allowed to edit bootup actions/,
     'script with the wrong start or stop letter is rejected');

$out = run_cgi(0, 'demo');
like($out, qr/demo-action-body/, 'known init.d action is shown');

$out = run_cgi(1, 2, '10', 'local', 0, 'S');
like($out, qr/runlevel-body/, 'known runlevel script is shown');

done_testing();
