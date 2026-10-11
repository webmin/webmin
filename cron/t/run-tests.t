#!/usr/bin/perl
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
my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);

open(my $cfh, ">", "$confdir/config") or die "config: $!";
print $cfh "os_type=generic-linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);
make_path("$confdir/cron");
my $miniservconf = "$confdir/miniserv.conf";
open(my $mfh, ">", $miniservconf) or die "miniserv.conf: $!";
print $mfh "root=$rootdir\n";
close($mfh);

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'cron';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$rootdir/cron") or die "chdir: $!";
require "$rootdir/cron/cron-lib.pl";

my $other = "/tmp/other-crontab";
my $file = "/tmp/test-crontab";
my @jobs = (
	{ 'index' => 0, 'file' => $other, 'type' => 0 },
	{ 'index' => 1, 'file' => $file, 'type' => 0 },
	{ 'index' => 2, 'file' => $file, 'type' => 0 },
	{ 'index' => 3, 'file' => $file, 'name' => 'PATH' },
	{ 'index' => 4, 'file' => $file, 'type' => 0 },
	{ 'index' => 5, 'file' => $file, 'type' => 0 },
	{ 'index' => 6, 'file' => $other, 'type' => 0 },
	);
my @leading_jobs = (
	{ 'index' => 0, 'file' => $file, 'type' => 0 },
	{ 'index' => 1, 'file' => $file, 'type' => 0 },
	);

is(get_cron_move_target(\@jobs, 4, "up"), $jobs[3],
	"up targets the previous entry");
is(get_cron_move_target(\@jobs, 2, "down"), $jobs[3],
	"down targets the next entry");
is(get_cron_move_target(\@jobs, 5, "top"), $jobs[1],
	"top targets the first entry in the same file");
is(get_cron_move_target(\@leading_jobs, 1, "top"), $leading_jobs[0],
	"top can target the first entry in the full list");
is(get_cron_move_target(\@jobs, 1, "bottom"), $jobs[5],
	"bottom targets the last entry in the same file");
is(get_cron_move_target(\@jobs, 1, "up"), $jobs[0],
	"up returns an entry from another file for caller validation");
is(get_cron_move_target(\@jobs, 0, "top"), undef,
	"top has no target for the first entry");
is(get_cron_move_target(\@jobs, 5, "bottom"), undef,
	"bottom has no target for the last entry in a file");

ok(cron_move_affects_env(\@jobs, $jobs[2], $jobs[3]),
	"an adjacent variable affects a move");
ok(cron_move_affects_env(\@jobs, $jobs[5], $jobs[1]),
	"an intermediate variable affects a top move");
ok(cron_move_affects_env(\@jobs, $jobs[1], $jobs[5]),
	"an intermediate variable affects a bottom move");
ok(!cron_move_affects_env(\@jobs, $jobs[1], $jobs[2]),
	"ordinary jobs can move without a variable");
ok(!cron_move_affects_env(\@jobs, $jobs[0], $jobs[6]),
	"variables in another file do not affect a move");

my $cronfile = "$vardir/crontab";
my $crondir = "$vardir/crontabs";
make_path($crondir);
open(my $modfh, ">", "$confdir/cron/config") or die "cron config: $!";
print $modfh "single_file=$cronfile\n";
print $modfh "cron_dir=$crondir\n";
print $modfh "system_crontab=$vardir/system-crontab\n";
print $modfh "cronfiles_dir=$vardir/cron.d\n";
print $modfh "vixie_cron=1\n";
close($modfh);
make_path("$vardir/cron.d");

# Reset the crontab fixture to its original contents.
sub write_crontab
{
open(my $fh, ">", $cronfile) or die "crontab: $!";
print $fh "* * * * * echo first\n";
print $fh "* * * * * echo second\n";
print $fh "PATH=/usr/bin\n";
print $fh "* * * * * echo third\n";
print $fh "* * * * * echo fourth\n";
close($fh);
}

# Return the current crontab fixture contents.
sub read_crontab_fixture
{
open(my $fh, "<", $cronfile) or die "crontab: $!";
local $/;
my $contents = <$fh>;
close($fh);
return $contents;
}

# Write the requested module ACL values for the CGI subprocess.
sub seed_acl
{
my (%acl) = @_;
open(my $fh, ">", "$confdir/cron/admin.acl") or die "admin.acl: $!";
foreach my $key (sort keys %acl) {
	print $fh "$key=$acl{$key}\n";
	}
close($fh);
}

# Encode one form value for an application/x-www-form-urlencoded body.
sub url_encode
{
my ($value) = @_;
$value = "" if (!defined($value));
$value =~ s/([^A-Za-z0-9._~-])/sprintf("%%%02X", ord($1))/ge;
return $value;
}

# Serialize a hash of scalar or array form values.
sub form_body
{
my ($form) = @_;
my @pairs;
foreach my $key (sort keys %$form) {
	my @values = ref($form->{$key}) eq "ARRAY" ?
		@{$form->{$key}} : ($form->{$key});
	push(@pairs, map { url_encode($key)."=".url_encode($_) } @values);
	}
return join("&", @pairs);
}

# Run one Cron CGI with the supplied form and isolated Webmin environment.
sub run_cgi
{
my ($cgi, $form) = @_;
my $body = form_body($form);
my %env = (
	'PATH' => $ENV{'PATH'},
	'WEBMIN_CONFIG' => $confdir,
	'WEBMIN_VAR' => $vardir,
	'FOREIGN_MODULE_NAME' => 'cron',
	'FOREIGN_ROOT_DIRECTORY' => $rootdir,
	'MINISERV_CONFIG' => $miniservconf,
	'REMOTE_USER' => 'admin',
	'BASE_REMOTE_USER' => 'admin',
	'REQUEST_METHOD' => 'POST',
	'SCRIPT_NAME' => "/cron/$cgi",
	'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
	'CONTENT_LENGTH' => length($body),
	'SERVER_NAME' => 'localhost',
	'SERVER_PORT' => '10000',
	'HTTP_HOST' => 'localhost:10000',
	);
my $errfh = gensym();
local %ENV = %env;
my $pid = IPC::Open3::open3(my $in, my $out, $errfh,
	$^X, "-I$rootdir", "$rootdir/cron/$cgi");
print $in $body;
close($in);
local $/;
my $stdout = <$out>;
my $stderr = <$errfh>;
$stdout = "" if (!defined($stdout));
$stderr = "" if (!defined($stderr));
close($out);
close($errfh);
waitpid($pid, 0);
return { 'out' => $stdout, 'err' => $stderr, 'status' => $? >> 8 };
}

my %full_acl = (
	'mode' => 0,
	'command' => 1,
	'create' => 1,
	'delete' => 1,
	'move' => 1,
	'env' => 1,
	);

write_crontab();
my $original = read_crontab_fixture();
seed_acl(%full_acl, 'env' => 0);
my $result = run_cgi("move.cgi", { 'idx' => 4, 'top' => 1 });
like($result->{'out'}, qr/not allowed to edit environment variables/i,
	"top move cannot cross a protected variable");
is(read_crontab_fixture(), $original,
	"denied top move leaves the crontab unchanged");

$result = run_cgi("delete_cron.cgi", { 'idx' => 2 });
like($result->{'out'}, qr/job does not exist/i,
	"job delete endpoint rejects a variable row");
$result = run_cgi("save_cron.cgi", { 'idx' => 2 });
like($result->{'out'}, qr/job does not exist/i,
	"job save endpoint rejects a variable row");

seed_acl(%full_acl);
$result = run_cgi("delete_env.cgi", { 'idx' => 0 });
like($result->{'out'}, qr/environment variable does not exist/i,
	"variable delete endpoint rejects a job row");
$result = run_cgi("save_env.cgi", { 'idx' => 0 });
like($result->{'out'}, qr/environment variable does not exist/i,
	"variable save endpoint rejects a job row");

seed_acl(%full_acl, 'create' => 0);
$result = run_cgi("save_env.cgi", { 'new' => 1 });
like($result->{'out'}, qr/not allowed to create cron jobs/i,
	"creating a variable requires create permission");

seed_acl(%full_acl, 'delete' => 0);
$result = run_cgi("delete_env.cgi", { 'idx' => 2 });
like($result->{'out'}, qr/not allowed to edit cron jobs/i,
	"deleting a variable requires delete permission");

seed_acl(%full_acl, 'env' => 0);
$result = run_cgi("delete_jobs.cgi",
	{ 'd' => [ 3, 2 ], 'delete' => 1 });
like($result->{'out'}, qr/not allowed to edit environment variables/i,
	"bulk delete rejects a mixed selection without env permission");
is(read_crontab_fixture(), $original,
	"denied bulk delete does not partially change the crontab");

$result = run_cgi("delete_jobs.cgi", { 'd' => 0, 'disable' => 1 });
like($result->{'out'}, qr/^Location:/m,
	"a normal job can still be disabled without env permission");
like(read_crontab_fixture(), qr/^# \* \* \* \* \* echo first/m,
	"disabling a normal job updates only that row");
$result = run_cgi("delete_jobs.cgi", { 'd' => 0, 'enable' => 1 });
like($result->{'out'}, qr/^Location:/m,
	"a normal job can still be enabled without env permission");
is(read_crontab_fixture(), $original,
	"re-enabling the normal job restores the fixture");

seed_acl(%full_acl);
$result = run_cgi("move.cgi", { 'idx' => 4, 'top' => 1 });
like($result->{'out'}, qr/^Location:/m,
	"a user with env permission can move a job across a variable");
isnt(read_crontab_fixture(), $original,
	"the permitted top move changes the crontab");

done_testing();
