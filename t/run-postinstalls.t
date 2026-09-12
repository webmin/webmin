#!/usr/bin/perl
# Tests scheduler pause markers around module post-install scripts.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use IPC::Open3;
use Symbol qw(gensym);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
my $runner = File::Spec->catfile($root, 'run-postinstalls.pl');
my $tmp = tempdir(CLEANUP => 1);
my $config_dir = File::Spec->catdir($tmp, 'config');
my $var_dir = File::Spec->catdir($tmp, 'var');
my $extra_root = File::Spec->catdir($tmp, 'root');
my $module_dir = File::Spec->catdir($extra_root, 'pause-test');
my $sentinel = File::Spec->catfile($tmp, 'postinstall-ran');
make_path($config_dir, $var_dir, $module_dir);

write_text(File::Spec->catfile($config_dir, 'config'), "");
write_text(File::Spec->catfile($module_dir, 'module.info'),
	   "name=Pause test\ndesc=Pause test\n");
write_text(File::Spec->catfile($module_dir, 'postinstall.pl'), <<'EOF');
sub module_install
{
# A child that exits without exec also runs the runner's END block. It must not
# remove the parent's marker.
my $child = fork();
die "fork: $!" if (!defined($child));
exit(0) if (!$child);
waitpid($child, 0);
open(my $sentinel, ">", $ENV{'POSTINSTALL_SENTINEL'}) ||
	die "create post-install sentinel: $!";
my $marker = $ENV{'POSTINSTALL_PAUSE'}.".d/".$$;
my $state = -e $marker ? "paused\n" : "unpaused\n";
print $sentinel $state;
close($sentinel) || die "close post-install sentinel: $!";
}
1;
EOF

sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) || die "create $file: $!";
print $fh $text;
close($fh) || die "close $file: $!";
}

sub run_postinstalls
{
my ($pause, $set_pause) = @_;
my $pause_config = $set_pause ? "webmincron_pause=$pause\n" : "";
write_text(File::Spec->catfile($config_dir, 'miniserv.conf'),
	   "root=$root\n".
	   "extraroot_0=$extra_root\n".
	   "pidfile=$var_dir/miniserv.pid\n".
	   "logfile=$var_dir/miniserv.log\n".
	   $pause_config);
unlink($sentinel);

local $ENV{'WEBMIN_CONFIG'} = $config_dir;
local $ENV{'WEBMIN_VAR'} = $var_dir;
local $ENV{'POSTINSTALL_SENTINEL'} = $sentinel;
local $ENV{'POSTINSTALL_PAUSE'} = $pause;
my $stderr = gensym();
my $pid = open3(undef, my $stdout, $stderr, $^X, $runner, 'pause-test');
local $/;
my $out = <$stdout> // '';
my $err = <$stderr> // '';
waitpid($pid, 0);
return ($? >> 8, $out, $err);
}

my $pause = File::Spec->catfile($var_dir, 'webmincron-pause');
my ($status, $output, $error) = run_postinstalls($pause, 0);
is($status, 0, 'post-install runner exits successfully');
is(read_text($sentinel), "paused\n",
	'forked child does not remove the runner\'s marker');
ok(-d $pause.'.d', 'pause directory remains after the runner exits');
is_deeply([ numeric_markers($pause.'.d') ], [],
	  'post-install marker is removed on exit');
is($error, '', 'successful pause setup reports no error');

# A runner using a custom path must leave another runner's marker intact.
my $custom_pause = File::Spec->catfile($var_dir, 'custom-pause');
my $custom_dir = $custom_pause.'.d';
make_path($custom_dir);
my $other_marker = File::Spec->catfile($custom_dir, $$);
write_text($other_marker, "");
($status, $output, $error) = run_postinstalls($custom_pause, 1);
is($status, 0, 'runner succeeds with a configured pause path');
is(read_text($sentinel), "paused\n", 'runner uses the configured pause path');
is_deeply([ numeric_markers($custom_dir) ], [ "$$" ],
	  'runner removes only its own marker');
is($error, '', 'overlapping pause markers report no error');
unlink($other_marker);

# Failure to create the shared directory must not skip post-install scripts.
my $blocker = File::Spec->catfile($tmp, 'not-a-directory');
write_text($blocker, "");
my $invalid_pause = File::Spec->catfile($blocker, 'webmincron-pause');
($status, $output, $error) = run_postinstalls($invalid_pause, 1);
is($status, 0, 'pause setup failure does not stop the runner');
is(read_text($sentinel), "unpaused\n",
   'module post-install still runs when pause setup fails');
like($error, qr/^Cannot pause scheduled jobs:/m,
     'pause setup failure is reported');

sub read_text
{
my ($file) = @_;
open(my $fh, '<', $file) || die "open $file: $!";
local $/;
my $text = <$fh>;
close($fh);
return $text;
}

sub numeric_markers
{
my ($dir) = @_;
opendir(my $dh, $dir) || die "open $dir: $!";
my @markers = grep { /^\d+$/ } readdir($dh);
closedir($dh);
return @markers;
}

done_testing();
