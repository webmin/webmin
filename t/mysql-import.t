#!/usr/bin/perl
# Check upload permissions before the MySQL import preparation can change them.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use FindBin;

# Observe the real open before the CGI writes any CSV bytes.
BEGIN {
	*CORE::GLOBAL::sysopen = sub (*$$;$) {
		no strict 'refs';
		my $fh = ref($_[0]) ? $_[0] : caller().'::'.$_[0];
		my $ok = CORE::sysopen($fh, $_[1], $_[2], $_[3] // 0666);
		if ($ok && $_[1] eq ($ImportFixture::path // '')) {
			my @st = stat($_[1]);
			$ImportFixture::created = [ $st[2] & 0777, $st[7] ];
			}
		return $ok;
		};
}

{
	package ImportFixture;
	our (%in, %access, %text, $path, $created, $prepared, $staged, $staging);
	# Stub only CGI setup; execute the actual upload branch and filesystem I/O.
	# Root runs can also take the staged branch, which needs the next three.
	sub ReadParseMime { }
	sub can_edit_db { 1 }
	sub error_setup { }
	sub supports_users { $staged }
	sub is_mysql_local { 1 }
	sub mysql_import_tempdir { $staging }
	sub mysql_import_tempname { $path }
	sub html_escape { $_[0] }
	sub text { join(' ', @_) }
	sub error { die "IMPORT_ERROR: $_[0]\n" }
	# Capture the written file before any ownership or permissions helper runs.
	sub set_mysql_command_file_permissions {
		my @st = stat($_[0]);
		open(my $fh, '<', $_[0]) or die $!;
		$prepared = [ $st[2] & 0777, do { local $/; <$fh> } ];
		close($fh) or die $!;
		die "UPLOAD_CAPTURED\n";
		}
}

# run_upload(mask, [existing], [staged]) exercises creation in a shared
# directory, on the fallback path or, as root, on the staged path.
sub run_upload
{
my ($mask, $existing, $staged) = @_;
my $dir = tempdir('webmin-mysql-upload-XXXXXX', DIR => '/tmp', CLEANUP => 1);
chmod(0755, $dir) or die $!;
local $ImportFixture::path = "$dir/items.csv";
local $ImportFixture::staged = $staged ? 1 : 0;
local $ImportFixture::staging = $dir;
local $ImportFixture::created;
local $ImportFixture::prepared;
local %ImportFixture::in = (db => 'fixture', mode => 1,
	upload_filename => 'items.csv', upload => "1,private fixture\n");
local %ImportFixture::access;
local $INC{'./mysql-lib.pl'} = 1;

# Existing targets must be rejected without truncating their contents.
my $target = $existing && $existing eq 'symlink' ? "$dir/target.csv" :
	$ImportFixture::path;
if ($existing) {
	open(my $fh, '>', $target) or die $!;
	print $fh "existing fixture\n";
	close($fh) or die $!;
	chmod(0644, $target) or die $!;
	symlink($target, $ImportFixture::path) or die $! if $existing eq 'symlink';
	}

my $oldmask = umask($mask);
{
	package ImportFixture;
	do "$FindBin::Bin/../mysql/import.cgi";
}
my $error = $@;
umask($oldmask);

if ($existing) {
	like($error, qr/^IMPORT_ERROR: efileopen /, "$existing is rejected");
	ok(!defined($ImportFixture::created), 'no upload file was opened');
	ok(!defined($ImportFixture::prepared), 'import preparation was not reached');
	open(my $fh, '<', $target) or die $!;
	is(do { local $/; <$fh> }, "existing fixture\n", 'existing contents are unchanged');
	close($fh) or die $!;
	is((stat($target))[2] & 0777, 0644, 'existing permissions are unchanged');
	}
else {
	# Staged uploads are private from the start; fallback uploads keep the
	# umask mode, so a server that can read the temp directory still works.
	my $mode = $staged ? 0600 : 0666 & ~$mask;
	is($error, "UPLOAD_CAPTURED\n", 'upload reaches permission preparation');
	is_deeply($ImportFixture::created, [ $mode, 0 ],
		sprintf('upload is created with mode %04o before the first byte', $mode));
	is_deeply($ImportFixture::prepared, [ $mode, $ImportFixture::in{'upload'} ],
		'complete CSV keeps that mode until permissions are prepared');
	}
}

for my $mask (0000, 0002, 0022, 0077) {
	subtest sprintf('fallback upload with umask %04o', $mask) => sub { run_upload($mask) };
	subtest sprintf('staged upload with umask %04o', $mask) => sub {
		plan(skip_all => 'the staged branch is only reached as root') if ($< != 0);
		run_upload($mask, undef, 1);
		};
	}
for my $existing ('file', 'symlink') {
	subtest "reject existing $existing" => sub { run_upload(0022, $existing) };
	}
done_testing();
