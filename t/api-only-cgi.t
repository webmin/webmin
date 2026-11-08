#!/usr/bin/perl
# Exercise API-only checks through real initialization with temporary config.
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use Cwd qw(abs_path);
use IPC::Open3;
use Symbol qw(gensym);

my $root = abs_path("$FindBin::Bin/..");
my $dir = tempdir(TMPDIR => 1, CLEANUP => 1);
mkdir("$dir/var") or die $!;
mkdir("$dir/acl") or die $!;

# write_fixture(name, content): write only inside the temporary configuration.
sub write_fixture
{
my ($name, $content) = @_;
open(my $fh, '>', "$dir/$name") or die $!;
print $fh $content;
close($fh) or die $!;
}
write_fixture('config', "os_type=generic-linux\nos_version=0\nlang=en\n");
write_fixture('miniserv.conf', "root=$root\n");
write_fixture('webmin.acl', "api: acl\nordinary: acl\n");
write_fixture('api.acl', "api_only=virtual-server/remote.cgi\nrpc=1\n");
write_fixture('ordinary.acl', "rpc=1\n");
write_fixture('fixture.pl', <<'PERL');
use WebminCore;
my ($root, $endpoint, $bypass) = @ARGV;
$0 = "$root/acl/index.cgi";
$main::allow_api_only = $endpoint;
$main::allow_rpc_only = 1;
$main::no_acl_check = $bypass;
init_config();
print "ENTRY_REACHED rpc=", webmin_user_can_rpc(), "\n";
PERL

# request(user, endpoint, [bypass], [cli], [base-user])
# Run the same CGI initialization in a fresh process and capture its response.
sub request
{
my ($user, $endpoint, $bypass, $cli, $base) = @_;
local %ENV = %ENV;
delete @ENV{qw(FOREIGN_MODULE_NAME FOREIGN_ROOT_DIRECTORY
	FOREIGN_MODULE_SEC_CHECK REMOTE_USER_PROTO)};
@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR SERVER_ROOT REMOTE_USER BASE_REMOTE_USER
	MINISERV_CONFIG)} =
	($dir, "$dir/var", $root, $user, $base || $user, "$dir/miniserv.conf");
if ($cli) {
	# Local commands must keep their existing behavior.
	delete @ENV{qw(SCRIPT_NAME REQUEST_METHOD)};
	}
else {
	# Exercise the normal HTTP entry checks, including the standard error page.
	$ENV{'SCRIPT_NAME'} = '/acl/index.cgi';
	$ENV{'REQUEST_METHOD'} = 'GET';
	}
my $err = gensym();
my $pid = open3(my $in, my $out, $err, $^X, "-I$root",
	"$dir/fixture.pl", $root, $endpoint || '', $bypass || 0);
close($in);
my $response = do { local $/; <$out> };
my $errors = do { local $/; <$err> };
waitpid($pid, 0);
return ($? >> 8, $response, $errors);
}

# Other entry scripts and unrelated bypass flags cannot opt into this API.
foreach my $case (
	[ 'api', '', 0 ],
	[ 'api', 'other/api.cgi', 0 ],
	[ 'api', '', 1 ],
	[ 'mapped', '', 0, 0, 'api' ]) {
	my ($exit, $out, $err) = request(@$case);
	ok($exit, 'API account is rejected before the page runs');
	unlike($out, qr/ENTRY_REACHED/, 'page body did not execute');
	like($out, qr/This account can only use its assigned API/,
		'reports the API restriction') or diag($err);
	}

my ($exit, $out, $err) = request('api', 'virtual-server/remote.cgi');
is($exit, 0, 'declared API entry script is allowed') or diag($err);
like($out, qr/ENTRY_REACHED rpc=0/, 'API account cannot use general RPC');
($exit, $out, $err) = request('ordinary', '');
is($exit, 0, 'ordinary account is allowed') or diag($err);
like($out, qr/ENTRY_REACHED rpc=1/, 'ordinary RPC permission is retained');
($exit, $out, $err) = request('api', '', 0, 1);
is($exit, 0, 'CLI initialization is unchanged') or diag($err);
like($out, qr/ENTRY_REACHED/, 'CLI body executes');
done_testing();
