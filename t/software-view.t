#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Copy qw(copy);
use File::Spec;
use File::Temp qw(tempdir);
use IPC::Open3;
use Symbol qw(gensym);
use Cwd qw(abs_path getcwd);

our (%files, %package_files, $check_calls);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
my $lib = File::Spec->catfile($root, 'software', 'view-lib.pl');
require $lib;

sub check_files
{
my ($package, $version) = @_;
$check_calls++;
%files = ( );
my $entries = $package_files{"$package\0".($version || '')} || [];
for(my $i = 0; $i < @$entries; $i++) {
	$files{$i,'path'} = $entries->[$i]->[0];
	$files{$i,'type'} = $entries->[$i]->[1];
	}
return scalar(@$entries);
}

$package_files{"safe-package\0".'1.0'} = [
	[ '/usr/bin/safe-tool', 0 ],
	[ '/etc/safe-tool.conf', 5 ],
	[ '/usr/share/safe-tool', 1 ],
	[ '/usr/bin/safe-tool-link', 3 ],
	];
$package_files{"other-package\0".'1.0'} = [
	[ '/usr/bin/other-tool', 0 ],
	];

ok(can_view_package_file('safe-package', '1.0', '/usr/bin/safe-tool'),
	'allows a regular file listed by the selected package');
ok(can_view_package_file('safe-package', '1.0', '/etc/safe-tool.conf'),
	'allows an editable file listed by the selected package');
ok(!can_view_package_file('safe-package', '1.0',
	'/var/webmin/sessiondb'),
	'rejects an arbitrary file not listed by the selected package');
ok(!can_view_package_file('safe-package', '1.0',
	'/usr/bin/../var/webmin/sessiondb'),
	'rejects a traversal path not returned by the package manager');
ok(!can_view_package_file('safe-package', '1.0', '/usr/bin/other-tool'),
	'rejects a file listed by a different package');
ok(!can_view_package_file('safe-package', '1.0', '/usr/share/safe-tool'),
	'rejects package directories');
ok(!can_view_package_file('safe-package', '1.0', '/usr/bin/safe-tool-link'),
	'rejects package links');
ok(!can_view_package_file(undef, '1.0', '/usr/bin/safe-tool'),
	'rejects requests without a package name');
ok(!can_view_package_file('safe-package', '1.0', undef),
	'rejects requests without a file path');
$check_calls = 0;
ok(!can_view_package_file('../safe-package', '1.0', '/usr/bin/safe-tool'),
	'rejects package names containing path traversal');
ok(!can_view_package_file('--root=/tmp', '1.0', '/usr/bin/safe-tool'),
	'rejects package names that could become command options');
is($check_calls, 0, 'rejects invalid package names before calling the backend');

sub urlize
{
my ($value) = @_;
$value =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
return $value;
}

sub run_view_cgi
{
my ($dir, $query, $path_info, $allowed_file) = @_;
my $cwd = getcwd();
chdir($dir) or die "chdir($dir): $!";
my $err = gensym();
local %ENV = (
	%ENV,
	REQUEST_METHOD   => 'GET',
	QUERY_STRING     => $query,
	PATH_INFO        => $path_info || '',
	TEST_ALLOWED_FILE => $allowed_file,
	);
my $pid = open3(my $in, my $out, $err, $^X, './view.cgi');
close($in);
local $/;
my $stdout = <$out> // '';
my $stderr = <$err> // '';
close($out);
close($err);
waitpid($pid, 0);
my $status = $? >> 8;
chdir($cwd) or die "chdir($cwd): $!";
return ($status, $stdout, $stderr);
}

subtest 'view CGI enforces package file validation' => sub {
	my $dir = tempdir(CLEANUP => 1);
	copy(File::Spec->catfile($root, 'software', 'view.cgi'),
	     File::Spec->catfile($dir, 'view.cgi')) or die "copy view.cgi: $!";
	copy($lib, File::Spec->catfile($dir, 'view-lib.pl'))
		or die "copy view-lib.pl: $!";

	my $stub = File::Spec->catfile($dir, 'software-lib.pl');
	open(my $stub_fh, '>', $stub) or die "open $stub: $!";
	print {$stub_fh} <<'PERL';
our (%in, %text, %files);
$text{'list_enotpackage'} = 'Cannot view this package file';
sub ReadParse {
	foreach my $item (split(/&/, $ENV{'QUERY_STRING'} || '')) {
		my ($key, $value) = split(/=/, $item, 2);
		$value = '' if !defined($value);
		$value =~ tr/+/ /;
		$value =~ s/%(..)/pack('c', hex($1))/ge;
		$in{$key} = $value;
		}
}
sub check_files {
	%files = ( );
	return 0 if ($_[0] ne 'safe-package' || $_[1] ne '1.0');
	$files{0,'path'} = $ENV{'TEST_ALLOWED_FILE'};
	$files{0,'type'} = 0;
	return 1;
}
sub error {
	print "Content-type: text/plain\n\n$_[0]\n";
	exit;
}
sub guess_mime_type { return 'text/plain'; }
sub get_buffer_size { return 1024; }
sub text { return join(': ', @_); }
1;
PERL
	close($stub_fh) or die "close $stub: $!";

	my $allowed = File::Spec->catfile($dir, 'allowed.txt');
	my $secret = File::Spec->catfile($dir, 'secret.txt');
	open(my $allowed_fh, '>', $allowed) or die "open $allowed: $!";
	print {$allowed_fh} "allowed contents\n";
	close($allowed_fh) or die "close $allowed: $!";
	open(my $secret_fh, '>', $secret) or die "open $secret: $!";
	print {$secret_fh} "secret contents\n";
	close($secret_fh) or die "close $secret: $!";

	my $base = 'package=safe-package&version=1.0&file=';
	my ($status, $out, $err) =
		run_view_cgi($dir, $base.urlize($allowed), '', $allowed);
	is($status, 0, 'listed package file request exits cleanly')
		or diag($err);
	like($out, qr/allowed contents/, 'listed package file is returned');

	($status, $out, $err) =
		run_view_cgi($dir, $base.urlize($secret), '', $allowed);
	is($status, 0, 'arbitrary file rejection exits cleanly')
		or diag($err);
	unlike($out, qr/secret contents/, 'arbitrary file contents are not returned');
	like($out, qr/Cannot view this package file/,
	     'arbitrary file request is rejected');

	($status, $out, $err) = run_view_cgi($dir, '', $secret, $allowed);
	is($status, 0, 'legacy PATH_INFO rejection exits cleanly')
		or diag($err);
	unlike($out, qr/secret contents/, 'PATH_INFO file contents are not returned');

	my $link = File::Spec->catfile($dir, 'allowed-link.txt');
	SKIP: {
		skip('symlinks are not available', 2) if !symlink($secret, $link);
		($status, $out, $err) =
			run_view_cgi($dir, $base.urlize($link), '', $link);
		is($status, 0, 'symlink rejection exits cleanly')
			or diag($err);
		unlike($out, qr/secret contents/,
		       'validated path cannot be replaced with a symlink');
	}
};

done_testing();
