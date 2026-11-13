#!/usr/bin/perl
# Check RPM extraction routes with mocks, or real bsdtar on a disposable VM.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Basename qw(fileparse);
use File::Copy qw(copy);
use JSON::PP qw(encode_json decode_json);
use POSIX ();

our ($live, @systems);
BEGIN {
	# Observe legacy ownership commands without changing workstation files.
	*CORE::GLOBAL::system = sub {
		return CORE::system(@_) if ($_[0] =~ /^mkdir /);
		push(@systems, [ @_ ]);
		return 0;
		};
}

$live = ($ENV{'FILEMIN_RPM_VM_TEST'} || '') eq '1';
die "Live extraction requires a disposable root Linux VM\n"
	if ($live && ($^O ne 'linux' || $> != 0));
my $root = "$FindBin::Bin/../..";
my $theme = $ENV{'AUTHENTIC_THEME_SOURCE'} ||
	"$root/../authentic-theme-src";
my $task = tempdir('filemin-rpm-XXXXXX', DIR => '/tmp', CLEANUP => 1);
our (%in, %text, %access, @allowed_paths, $cwd, $path, $name, $mime);
our ($available, $mock_status, $mock_output, @commands, @deleted, %errors);

# Load the shipped messages so missing language keys fail these checks too.
my %messages;
for my $file ("$root/filemin/lang/en", "$theme/lang/en") {
	next if (!-f $file);
	open(my $fh, '<', $file) or die "$file: $!";
	while (<$fh>) {
		chomp;
		$messages{$1} = $2 if (/^([^=]+)=(.*)$/);
		}
	close($fh);
	}

# load_sub(file, name) loads the real function without Webmin initialization.
sub load_sub
{
my ($file, $name) = @_;
open(my $fh, '<', $file) or die "$file: $!";
my $source = do { local $/; <$fh> };
close($fh);
$source =~ /^(sub \Q$name\E\n\{\n.*?^\})/ms or die "Missing $name";
eval "no strict; $1";
die $@ if $@;
}

# Stub request setup and path checks; this suite tests extraction, not ACLs.
sub ReadParse { }
sub get_paths { }
sub get_entries_list { ($name) }
sub validate_filename_path { "$cwd/$_[0]" }
sub fm_checked_cwd_path_or_error { validate_filename_path(@_) }
sub check_allowed_path { }
sub clean_mimetype { $mime }
sub mimetype { $mime }
sub has_command { $_[0] eq 'bsdtar' && $available ? '/usr/bin/bsdtar' : undef }
sub make_dir { mkdir($_[0], $_[1]) }
sub error { die "EXTRACTION_ERROR: $_[0]\n" }
sub redirect { }
sub redirect_local { }
sub urlize { $_[0] }
sub extra_query { '' }
sub get_errors { %errors = %{$_[0]}; return '' }
sub file_name_extension_splitter { $_[0] =~ /^(.*)\.([^.]+)$/ }
sub unlink_file { push(@deleted, $_[0]); unlink($_[0]) }
# text(key, [values]) substitutes arguments into the real English messages.
sub text
{
my ($key, @values) = @_;
die "Missing language key: $key" if (!exists($text{$key}));
my $message = $text{$key};
$message =~ s/\$(\d+)/$values[$1-1]/ge;
return $message;
}
sub html_escape
{
my ($s) = @_;
$s =~ s/&/&amp;/g;
$s =~ s/</&lt;/g;
$s =~ s/>/&gt;/g;
return $s;
}

# backquote_logged(command) executes only in the explicitly enabled VM mode.
sub backquote_logged
{
my ($cmd) = @_;
push(@commands, $cmd);
return `$cmd` if ($live);
$? = $mock_status;
return $mock_output;
}
sub backquote_command { backquote_logged(@_) }

load_sub("$root/web-lib-funcs.pl", 'simplify_path');
load_sub("$root/filemin/filemin-lib.pl", 'rpm_extract_command');
load_sub("$root/filemin/filemin-lib.pl", 'extract_files');
$INC{'./filemin-lib.pl'} = 1;
$ENV{'THEME_ROOT'} = $theme;
$INC{"$theme/extensions/file-manager/file-manager-lib.pl"} = 1;
my @routes = ('classic', 'upload');
push(@routes, 'theme') if (-f "$theme/extensions/file-manager/extract.cgi");

# write_file(path, data) writes only a fixture beneath the task directory.
sub write_file
{
my ($file, $data) = @_;
open(my $fh, '>', $file) or die "$file: $!";
print {$fh} $data;
close($fh) or die $!;
}

# prepare_case(route, label) creates an independent request and output tree.
sub prepare_case
{
my ($route, $label) = @_;
my $case = "$task/$route-$label";
make_path("$case/work", "$case/outside");
$cwd = "$case/work";
$path = $cwd;
$name = "odd ' package.rpm";
%in = (file => $name, overwrite_existing => 1,
	overwrite_efiles => 'true', delete => 1);
%access = (work_as_root => 1);
@allowed_paths = ($cwd);
%text = %messages;
%errors = ();
@commands = @deleted = @systems = ();
$mime = 'application/x-rpm';
$available = 1;
$mock_status = 0;
$mock_output = '';
write_file("$cwd/$name", "mock RPM\n");
my $target = $route eq 'upload' ? $cwd : "$cwd/odd ' package";
return ($case, $target, "$cwd/$name");
}

# run_route(route) runs the actual upload function or CGI and returns errors.
sub run_route
{
my ($route) = @_;
if ($route eq 'upload') {
	return [ extract_files([ { path => $cwd, file => $name } ], 1) ];
	}
elsif ($route eq 'classic') {
	do "$root/filemin/extract.cgi";
	return $@ ? [ $@ ] : [ ];
	}
else {
	do "$theme/extensions/file-manager/extract.cgi";
	die $@ if $@;
	return [ values %errors ];
	}
}

for my $route (@routes) {
	subtest "$route missing bsdtar" => sub {
		my (undef, $target, $archive) = prepare_case($route, 'missing');
		$available = 0;
		my $errors = run_route($route);
		like(join(' ', @$errors), qr/bsdtar/, 'reports the missing tool');
		like(join(' ', @$errors), qr/Install.*bsdtar.*libarchive-tools/,
			'names the packages to install');
		is_deeply(\@commands, [], 'no extractor is started');
		is_deeply(\@systems, [], 'no ownership changes run');
		ok(-f $archive, 'archive is retained');
		ok(!-e $target, 'no output directory is created')
			if ($route ne 'upload');
		};
	if (!$live) {
		subtest "$route command failure" => sub {
			my (undef, undef, $archive) = prepare_case($route, 'failure');
			$mock_status = 256;
			$mock_output = '<fixture extraction error>';
			my $errors = run_route($route);
			like(join(' ', @$errors), qr/fixture extraction error/,
				'reports the extractor diagnostic');
			ok(-f $archive, 'failed archive is retained');
			is_deeply(\@systems, [], 'failure cannot run recursive chown');
			is_deeply(\@deleted, [], 'failure cannot delete the archive');
			};
		subtest "$route source RPM" => sub {
			prepare_case($route, 'source');
			$mime = 'application/x-source-rpm';
			is_deeply(run_route($route), [], 'source RPM is accepted');
			is(scalar(@commands), 1, 'one extractor is run');
			like($commands[0], qr/bsdtar.*--no-same-permissions/,
				'uses bsdtar without privileged permissions');
			unlike($commands[0], qr/--safe-writes/,
				'does not require libarchive 3.4.2');
			is_deeply(\@systems, [], 'RPMs never run recursive chown');
			};
		if ($route ne 'classic') {
			for my $fresh (0, 1) {
				subtest "$route empty failure directory fresh=$fresh" => sub {
					my (undef, $target, $archive) =
						prepare_case($route, "empty-$fresh");
					if ($fresh) {
						$in{'overwrite_existing'} = 0;
						$in{'overwrite_efiles'} = 'false';
						$target = "$cwd/odd ' package";
						}
					else {
						make_path($target);
						}
					$mock_status = 256;
					$mock_output = 'Invalid archive';
					my $errors = run_route($route);
					like(join(' ', @$errors), qr/Failed to extract.*Invalid archive/,
						'reports the translated failure');
					is(-d $target ? 1 : 0, $fresh ? 0 : 1,
						'only a newly created empty directory is removed');
					ok(-f $archive, 'failed archive is retained');
					};
				}
			}
		next;
		}

	for my $kind (qw(normal fresh absolute dotdot symlink existing-link hardlink
			 corrupt fresh-corrupt partial real source)) {
		subtest "$route live $kind" => sub {
			my ($case, $target, $archive) = prepare_case($route, $kind);
			my $fresh = $kind =~ /^(fresh|fresh-corrupt|partial)$/;
			if ($fresh) {
				$in{'overwrite_existing'} = 0;
				$in{'overwrite_efiles'} = 'false';
				$target = "$cwd/odd ' package";
				}
			else {
				make_path($target);
				write_file("$target/unrelated", 'unrelated');
				}
			$mime = 'application/x-source-rpm' if ($kind eq 'source');
			my $outside = "$case/outside/marker";
			write_file($outside, 'unchanged');
			my $entry = 'file.txt';
			if ($kind eq 'absolute') {
				$entry = $outside;
				}
			elsif ($kind eq 'dotdot') {
				$entry = $route eq 'upload' ? '../outside/marker' :
					'../../outside/marker';
				}
			elsif ($kind eq 'existing-link') {
				symlink("$case/outside", "$target/escape") or die $!;
				}
			elsif ($kind eq 'hardlink') {
				link($outside, "$target/file.txt") or die $!;
				}
			my $spec = "$case/spec.json";
			write_file($spec, encode_json({ kind => $kind,
				archive => $archive, entry => $entry,
				outside => "$case/outside" }));
			is(CORE::system('python3', "$FindBin::Bin/rpm-fixture.py",
				$spec), 0, 'RPM fixture is built');
			chown(65534, 65534, $archive) or die $!;
			my $errors = run_route($route);
			my $fails = $kind =~ /^(dotdot|symlink|existing-link|corrupt|fresh-corrupt|partial)$/;
			if ($fails) {
				ok(@$errors, 'unsafe or corrupt extraction reports failure');
				ok(-f $archive, 'failed archive is retained');
				ok(!-e $target, 'new empty output directory is removed')
					if ($kind eq 'fresh-corrupt' && $route ne 'classic');
				ok(-f "$target/file.txt", 'partially extracted files are retained')
					if ($kind eq 'partial');
				}
			else {
				is_deeply($errors, [], 'extraction succeeds');
				my $file = $kind eq 'absolute' ? "$target$outside" :
					$kind eq 'real' ? "$target/opt/filemin-rpm-test/file.txt" :
					$kind eq 'source' ? "$target/fixture.spec" :
					"$target/file.txt";
				ok(-f $file, 'payload is extracted under the destination');
				my @st = stat($file);
				is($st[4], $route eq 'upload' ? 65534 : 0,
					'owner comes from Filemin, not the package');
				is($st[2] & 06000, 0, 'setuid and setgid bits are removed');
				if ($fresh) {
					is((stat($target))[4], $route eq 'upload' ? 65534 : 0,
						'new destination has the intended owner');
					}
				if ($kind eq 'normal') {
					is(readlink("$target/relative-link"), 'file.txt',
						'relative symlink is preserved');
					is(readlink("$target/absolute-link"), $outside,
						'absolute symlink is preserved without following it');
					}
				ok(!-e $archive, 'successful upload or theme extraction deletes archive')
					if ($route ne 'classic');
				}
			open(my $fh, '<', $outside) or die $!;
			is(do { local $/; <$fh> }, 'unchanged', 'outside contents are unchanged');
			close($fh);
			is((stat($outside))[4], 0, 'outside ownership is unchanged');
			is((stat("$target/unrelated"))[4], 0,
				'unrelated destination ownership is unchanged')
				if (!$fresh);
			is_deeply(\@systems, [], 'no recursive ownership command runs');
			};
		}
	}

if ($live) {
	subtest 'upload runs as an ordinary Unix account' => sub {
		my ($case, $target, $archive) = prepare_case('upload', 'nonroot');
		my $spec = "$case/spec.json";
		write_file($spec, encode_json({ kind => 'normal', archive => $archive,
			entry => 'file.txt', outside => "$case/outside" }));
		is(CORE::system('python3', "$FindBin::Bin/rpm-fixture.py", $spec),
			0, 'RPM fixture is built');
		chmod(0711, $task) or die $!;
		chown(65534, 65534, $cwd, $archive) == 2 or die $!;
		my $pid = fork();
		defined($pid) or die $!;
		if (!$pid) {
			# Drop all Unix credentials only in this disposable VM child.
			$) = '65534 65534';
			POSIX::setgid(65534) == 0 or die $!;
			POSIX::setuid(65534) == 0 or die $!;
			my $errors = run_route('upload');
			write_file("$cwd/result.json", encode_json({ errors => $errors,
				uid => $>, owner => (stat("$cwd/file.txt"))[4],
				mode => (stat("$cwd/file.txt"))[2] & 06000 }));
			POSIX::_exit(0);
			}
		waitpid($pid, 0);
		is($?, 0, 'unprivileged child succeeds');
		open(my $fh, '<', "$cwd/result.json") or die $!;
		my $result = decode_json(do { local $/; <$fh> });
		close($fh);
		is_deeply($result, { errors => [], uid => 65534,
			owner => 65534, mode => 0 },
			'extraction keeps the Unix account and removes privileged modes');
		};
	}
done_testing();
