#!/usr/bin/perl
# Exercise chooser access checks with real CGI requests on a disposable VM.
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(abs_path getcwd);

plan skip_all => 'Set WEBMIN_CHOOSER_VM_TEST=1 on a disposable Linux VM'
	unless ($ENV{'WEBMIN_CHOOSER_VM_TEST'} || '') eq '1';
die "Disposable root Linux VM required\n" if ($^O ne 'linux' || $> != 0);
my $source = abs_path($ENV{'WEBMIN_CHOOSER_SOURCE'} ||
	"$FindBin::Bin/../chooser.cgi");
open(my $mc, '<', '/etc/webmin/miniserv.conf') or die $!;
my ($installed) = map { /^root=(.*)/ ? $1 : () } <$mc>;
close($mc);
die "Installed Webmin root not found\n" if (!$installed || !-d $installed);

# Keep configuration, file listings and CGI output inside the test directory.
my $task = tempdir('chooser-vm-XXXXXX', DIR => '/tmp', CLEANUP => 1);
my $allowed = "$task/allowed";
my $outside = "$task/outside";
my $config = "$task/config";
make_path("$allowed/sub", $outside, "$outside$allowed", $config, "$task/var");
chmod(0755, $task) or die $!;
symlink($outside, "$allowed/escape") or die $!;
symlink("$allowed/sub", "$allowed/internal") or die $!;
symlink($allowed, "$task/root-alias") or die $!;

# write_file(path, contents) creates a fixture with the given contents.
sub write_file
{
my ($path, $contents) = @_;
open(my $fh, '>', $path) or die "$path: $!";
print {$fh} $contents;
close($fh) or die $!;
}

write_file("$allowed/chooser-root-marker.txt", 'allowed root');
write_file("$allowed/sub/chooser-child-marker.txt", 'allowed child');
write_file("$outside/chooser-outside-marker.txt", 'outside');
write_file("$outside$allowed/chooser-outside-marker.txt", 'mirrored root');
write_file("$config/config", "os_type=redhat-linux\nos_version=10\nlang=en\n");
write_file("$config/miniserv.conf", "root=$installed\nport=10000\n");
write_file("$config/webmin.acl", "root: webmin\n");

# encode(value) escapes a single query parameter for the real CGI parser.
sub encode
{
my ($value) = @_;
$value =~ s/([^A-Za-z0-9_.~-])/sprintf('%%%02X', ord($1))/ge;
return $value;
}

# request(root, otherdirs, unix_user, chroot, file) runs the unmodified CGI.
sub request
{
my ($root, $otherdirs, $unix_user, $chroot, $file) = @_;
write_file("$config/root.acl",
	"root=$root\notherdirs=$otherdirs\nfileunix=$unix_user\n");
local %ENV = %ENV;
@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR MINISERV_CONFIG SERVER_ROOT
	SCRIPT_NAME SCRIPT_FILENAME REMOTE_USER REQUEST_METHOD
	SERVER_NAME SERVER_PORT HTTP_HOST HTTP_REFERER QUERY_STRING)} =
	($config, "$task/var", "$config/miniserv.conf", $installed,
	 '/chooser.cgi', $source, 'root', 'GET',
	 'localhost', '10000', 'localhost:10000', 'http://localhost:10000/',
	 'frame=1&type=0&chroot='.encode($chroot).'&file='.encode($file));
my $cwd = getcwd();
chdir($installed) or die $!;
open(my $fh, '-|', $^X, "-I$installed", $source) or die $!;
my $html = do { local $/; <$fh> };
close($fh);
my $status = $?;
chdir($cwd) or die $!;
return ($html || '', $status);
}

# Check both privileged browsing and the existing Unix-user switch.
my @users = ('root', 'nobody');
for my $user (@users) {
	my @user = getpwnam($user);
	die "Missing Unix fixture account $user\n" if (!@user);
	for my $case (
		[ 'ordinary path', $allowed, '', '/', "$allowed/sub/", 'child' ],
		[ 'accepted chroot', $allowed, '', $allowed, '/', 'root' ],
		[ 'parent traversal', $allowed, '', "$allowed/../outside", '/', 'denied' ],
		[ 'symlink chroot', $allowed, '', "$allowed/escape", '/', 'denied' ],
		[ 'child symlink escape', $allowed, '', $allowed, '/escape/', 'root' ],
		[ 'internal symlink', $allowed, '', $allowed, '/internal/', 'child' ],
		[ 'root alias', "$task/root-alias", '', '/', "$allowed/sub/", 'child' ],
		[ 'other allowed directory', $allowed, $outside, '/', "$outside/", 'outside' ],
		[ 'allowed child symlink', $allowed, $outside, $allowed, '/escape/', 'outside' ],
		[ 'unsafe fallback', $allowed, '', $outside, "$allowed/", 'denied' ],
		[ 'missing path fallback', $allowed, '', $allowed, '/missing/', 'root' ],
		[ 'unrestricted user', '/', '', '/', "$outside/", 'outside' ]) {
		subtest "$user: $case->[0]" => sub {
			my ($label, $root, $otherdirs, $chroot, $file, $expected) = @$case;
			my ($html, $status) = request($root, $otherdirs, $user, $chroot, $file);
			is($status, $expected eq 'denied' ? 256 : 0,
				'CGI returns the expected exit status');
			if ($expected eq 'denied') {
				# Rejected chroots must show an error instead of a listing.
				like($html, qr/Listing failed/, 'unsafe request reports an error');
				}
			else {
				# Require the intended listing, not merely an empty response.
				like($html, qr/chooser-\Q$expected\E-marker\.txt/,
					'expected directory is listed');
				}
			if ($expected ne 'outside') {
				# Outside names are allowed only by an explicit ACL entry.
				unlike($html, qr/chooser-outside-marker\.txt/,
					'outside directory is not listed');
				}
			};
		}
	}
done_testing();
