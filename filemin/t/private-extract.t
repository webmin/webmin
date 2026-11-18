#!/usr/bin/perl
# Check that archives are extracted through a private directory and merged
# into place without following symlinks left by earlier archives.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use File::Basename qw(dirname);
use Cwd qw(getcwd);
use POSIX ();
use Fcntl ();
use File::Path ();

my $root = "$FindBin::Bin/../..";
my $tar = `command -v tar 2>/dev/null`;
chomp($tar);
plan skip_all => 'tar is required' if (!$tar);
my $task = tempdir('filemin-extract-XXXXXX', DIR => File::Spec->tmpdir(),
		   CLEANUP => 1);
our (@allowed_paths, %text);

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

# Load the shipped messages so missing language keys fail these checks too.
open(my $lang, '<', "$root/filemin/lang/en") or die $!;
while (<$lang>) {
	chomp;
	$text{$1} = $2 if (/^([^=]+)=(.*)$/);
	}
close($lang);

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

foreach my $name (qw(test_allowed_paths filemin_restricted_root
		     filemin_walk_tree filemin_drop_setid_file
		     filemin_drop_setid extract_in_private_dir
		     filemin_same_file filemin_tar_dirs filemin_merge_directory filemin_merge_extracted
		     filemin_rename_extracted filemin_decompress_command)) {
	load_sub("$root/filemin/filemin-lib.pl", $name);
	}

# write_file(path, data) writes a fixture file.
sub write_file
{
my ($file, $data) = @_;
open(my $fh, '>', $file) or die "$file: $!";
print {$fh} $data;
close($fh) or die $!;
}

# read_file(path) returns a fixture file's contents.
sub read_file
{
my ($file) = @_;
open(my $fh, '<', $file) or return undef;
my $data = do { local $/; <$fh> };
close($fh);
return $data;
}

# make_tar(name, &setup) builds an archive from a fresh source directory.
sub make_tar
{
my ($name, $setup) = @_;
my $src = "$task/src-$name";
make_path($src);
&$setup($src);
my $archive = "$task/$name.tar";
system($tar, 'cf', $archive, '-C', $src, '.') == 0 or die "tar failed";
return $archive;
}

# extract(archive, dir, overwrite) runs the helper with a tar command.
sub extract
{
my ($archive, $dir, $overwrite, $cmd) = @_;
my $tarfile = $cmd ? undef : $archive;
$cmd ||= "$tar xpf ".quotemeta($archive);
return extract_in_private_dir($dir, $overwrite,
	sub { return system("$cmd 2>/dev/null"); }, undef, undef, $tarfile);
}

# leftovers(dir) lists private extraction directories left behind.
sub leftovers
{
my ($dir) = @_;
opendir(my $dh, $dir) or return ();
my @rv = grep { /^\.filemin-extract-/ } readdir($dh);
closedir($dh);
return @rv;
}

@allowed_paths = ('/');
my $start = getcwd();
my $link_tar = make_tar('link', sub {
	symlink('../outside', "$_[0]/s") or die $!;
	});
my $through_tar = make_tar('through', sub {
	make_path("$_[0]/s");
	write_file("$_[0]/s/pwned", 'pwned');
	});

subtest 'second archive cannot write through a symlink' => sub {
	for my $overwrite (1, 0) {
		my $case = "$task/through-$overwrite";
		make_path("$case/work", "$case/outside");
		my ($st, @err) = extract($link_tar, "$case/work", $overwrite);
		is($st, 0, 'first archive extracts');
		is(readlink("$case/work/s"), '../outside',
		   'symlink is created');
		($st, @err) = extract($through_tar, "$case/work", $overwrite);
		is($st, 0, 'second archive extracts');
		is_deeply(\@err, [], 'no errors are reported');
		ok(!-e "$case/outside/pwned", 'nothing is written outside');
		if ($overwrite) {
			ok(!-l "$case/work/s" && -d "$case/work/s",
			   'symlink is replaced by the extracted directory');
			is(read_file("$case/work/s/pwned"), 'pwned',
			   'extracted file is in place');
			}
		else {
			is(readlink("$case/work/s"), '../outside',
			   'existing symlink is kept');
			}
		is_deeply([ leftovers("$case/work") ], [],
			  'private directory is removed');
		is(getcwd(), $start, 'current directory is restored');
		}
	};

subtest 'normal archive merges into existing directories' => sub {
	my $archive = make_tar('normal', sub {
		make_path("$_[0]/dir/sub");
		chmod(0700, "$_[0]/dir") && chmod(01775, "$_[0]/dir/sub") or die $!;
		write_file("$_[0]/dir/new.txt", 'new');
		write_file("$_[0]/dir/sub/deep.txt", 'deep');
		write_file("$_[0]/top.txt", 'top from archive');
		symlink('sub/deep.txt', "$_[0]/dir/rel-link") or die $!;
		symlink('/etc/passwd', "$_[0]/abs-link") or die $!;
		});
	for my $overwrite (1, 0) {
		my $case = "$task/normal-$overwrite/work";
		make_path("$case/dir/sub");
		chmod(0755, "$case/dir/sub") or die $!;
		chmod(0755, "$case/dir") or die $!;
		write_file("$case/dir/keep.txt", 'unrelated');
		write_file("$case/top.txt", 'existing');
		my ($st, @err) = extract($archive, $case, $overwrite);
		is($st, 0, 'archive extracts');
		is_deeply(\@err, [], 'no errors are reported');
		is((stat("$case/dir"))[2] & 0777, $overwrite ? 0700 : 0755,
		   'only overwrite restores the archived directory mode');
		is((stat("$case/dir/sub"))[2] & 07777, $overwrite ? 01775 : 0755,
		   'overwrite restores the sticky bit on a shared directory');
		is(read_file("$case/dir/keep.txt"), 'unrelated',
		   'unrelated file in a merged directory is kept');
		is(read_file("$case/dir/new.txt"), 'new', 'new file is added');
		is(read_file("$case/dir/sub/deep.txt"), 'deep',
		   'nested file is added');
		is(readlink("$case/dir/rel-link"), 'sub/deep.txt',
		   'internal relative symlink is preserved');
		is(readlink("$case/abs-link"), '/etc/passwd',
		   'absolute symlink is extracted as a link');
		is(read_file("$case/top.txt"),
		   $overwrite ? 'top from archive' : 'existing',
		   'existing file follows the overwrite setting');
		is_deeply([ leftovers($case) ], [],
			  'private directory is removed');
		}
	};

subtest 'a tar containing only a file keeps its parent permissions' => sub {
	my $src = "$task/implicit-src";
	my $dst = "$task/implicit-dst";
	make_path("$src/team", "$dst/team");
	chmod(0700, "$dst/team") or die $!;
	write_file("$src/team/note", 'hello');
	my $tarfile = "$task/implicit.tar";
	system($tar, 'cf', $tarfile, '-C', $src, 'team/note') == 0 or die $!;
	my ($status, @errors) = extract($tarfile, $dst, 1);
	is($status, 0, 'file extracted');
	is_deeply(\@errors, [], 'no merge errors');
	is((stat("$dst/team"))[2] & 0777, 0700, 'private parent stays private');
	};

subtest 'extraction requiring confirmation reports a collision' => sub {
	my $dir = "$task/confirm";
	make_path($dir);
	my $tar = make_tar('confirm', sub { write_file("$_[0]/report", 'archived') });
	write_file("$dir/report", 'current');
	my ($status, @errors) = extract($tar, $dir, undef);
	is($status, 0, 'archive was readable');
	like(join(' ', @errors), qr/report.*already exists/, 'names the skipped file');
	is(read_file("$dir/report"), 'current', 'keeps the existing file');
	};

subtest 'failed command discards incomplete output' => sub {
	my $dest = "$task/partial";
	make_path($dest);
	write_file("$dest/report", "original");
	my ($status) = extract_in_private_dir($dest, 1, sub {
		write_file('report', 'partial');
		write_file('new', 'unfinished');
		return 1;
		});
	is($status, 1, 'command failure is returned');
	is(read_file("$dest/report"), 'original', 'existing file kept');
	ok(!-e "$dest/new", 'incomplete file discarded');
	is_deeply([ leftovers($dest) ], [], 'temporary directory removed');
	};

subtest 'destination and conflicts' => sub {
	my $case = "$task/dest";
	make_path("$case/real", "$case/outside");
	symlink("$case/outside", "$case/link") or die $!;
	my ($st, @err) = extract($through_tar, "$case/link", 1);
	isnt($st, 0, 'symlinked destination is refused');
	like(join(' ', @err), qr/not a directory or is a symbolic link/,
	     'refusal is reported');
	opendir(my $dh, "$case/outside") or die $!;
	is(scalar(grep { !/^\./ } readdir($dh)), 0,
	   'nothing is written through the link');
	closedir($dh);

	# An extracted file never replaces an existing directory
	my $file_tar = make_tar('file-s',
				sub { write_file("$_[0]/s", 'file') });
	make_path("$case/real/s");
	write_file("$case/real/s/inner", 'inner');
	($st, @err) = extract($file_tar, "$case/real", 1);
	like(join(' ', @err), qr/directory with that name already exists/,
	     'file over directory is reported');
	is(read_file("$case/real/s/inner"), 'inner', 'directory is kept');

	# Names in errors are escaped
	my $odd = make_tar('odd', sub { write_file("$_[0]/<b>", 'x') });
	make_path("$case/odd/<b>");
	($st, @err) = extract($odd, "$case/odd", 1);
	like(join(' ', @err), qr/&lt;b&gt;/, 'file names are escaped');
	unlike(join(' ', @err), qr/<b>/, 'no raw HTML in errors');
	};

subtest 'read-only directories and dot entry' => sub {
	my $archive = make_tar('readonly', sub {
		make_path("$_[0]/ro");
		write_file("$_[0]/ro/f", 'f');
		chmod(0555, "$_[0]/ro") or die $!;
		chmod(0777, $_[0]) or die $!;
		});
	my $case = "$task/readonly/work";
	make_path($case);
	my ($st, @err) = extract($archive, $case, 1);
	is($st, 0, 'archive extracts');
	is_deeply(\@err, [], 'read-only directory is moved');
	is(read_file("$case/ro/f"), 'f', 'its contents are in place');
	is((stat("$case/ro"))[2] & 07777, 0555, 'its mode is restored');
	is((stat($case))[2] & 07777, 0755 & ~umask(),
	   'archive dot entry does not change the destination');
	chmod(0755, "$case/ro");
	};

SKIP: {
	my $zip = `command -v zip 2>/dev/null`;
	my $unzip = `command -v unzip 2>/dev/null`;
	chomp($zip, $unzip);
	skip 'zip and unzip are required', 1 if (!$zip || !$unzip);
	subtest 'zip archives' => sub {
		my $src = "$task/src-zip";
		make_path("$src/d/e");
		write_file("$src/d/e/f.txt", 'zip');
		my $archive = "$task/test.zip";
		system("cd ".quotemeta($src)." && $zip -qry ".
		       quotemeta($archive)." d") == 0 or die "zip failed";
		my $case = "$task/zip/work";
		make_path("$case/d");
		symlink("$task/zip", "$case/d/e") or die $!;
		my ($st, @err) = extract($archive, $case, 1,
			"$unzip -q -o -d . -- ".quotemeta($archive));
		is($st, 0, 'zip extracts');
		is(read_file("$case/d/e/f.txt"), 'zip', 'file is in place');
		ok(!-l "$case/d/e", 'symlinked directory is replaced');
		ok(!-e "$task/zip/f.txt", 'nothing is written through it');
		};
	}

subtest 'setuid and setgid bits' => sub {
	my $case = "$task/setid";
	make_path("$case/dir/sub/deeper", "$case/outside");
	my @files = ("$case/top", "$case/dir/one", "$case/dir/sub/two",
		     "$case/dir/sub/deeper/three", "$case/outside/target");
	foreach my $f (@files) {
		write_file($f, 'x');
		chmod(04755, $f) or die $!;
		}
	symlink("$case/outside/target", "$case/dir/link") or die $!;
	symlink("$case/outside", "$case/dir/linkdir") or die $!;
	chmod(02775, "$case/dir/sub") or die $!;
	SKIP: {
		skip 'setuid cannot be set here', 6
			if (((stat("$case/top"))[2] & 04000) == 0);
		filemin_drop_setid("$case/top");
		is((stat("$case/top"))[2] & 07777, 0755,
		   'single file is fixed');
		filemin_drop_setid("$case/dir", 1);
		is((stat("$case/dir/one"))[2] & 07777, 0755,
		   'depth 1 is fixed');
		is((stat("$case/dir/sub/two"))[2] & 06000, 04000,
		   'deeper levels are left alone');
		filemin_drop_setid("$case/dir", -1);
		is((stat("$case/dir/sub/deeper/three"))[2] & 07777, 0755,
		   'all levels are fixed');
		is((stat("$case/outside/target"))[2] & 04000, 04000,
		   'symlink targets are not changed');
		is((stat("$case/dir/sub"))[2] & 02000, 02000,
		   'directories keep setgid');
		}
	is(getcwd(), $start, 'current directory is restored');
	};

subtest 'upload extraction' => sub {
	# Stub request setup and path checks; this tests extraction only.
	local (*main::check_allowed_path, *main::validate_filename_path,
	       *main::mimetype, *main::has_command, *main::unlink_file);
	our ($cwd, %in);
	*main::check_allowed_path = sub { };
	*main::validate_filename_path = sub { "$cwd/$_[0]" };
	*main::mimetype = sub { 'application/x-tar' };
	*main::has_command = sub { $_[0] eq 'tar' ? $tar : undef };
	*main::unlink_file = sub { unlink(@_) };
	load_sub("$root/web-lib-funcs.pl", 'simplify_path');
	load_sub("$root/filemin/filemin-lib.pl", 'extract_files');
	for my $overwrite (1, 0) {
		my $case = "$task/upload-$overwrite";
		make_path("$case/work", "$case/outside");
		%in = (overwrite_existing => $overwrite);
		$cwd = "$case/work";
		for my $archive ($link_tar, $through_tar) {
			my ($file) = $archive =~ /([^\/]+)$/;
			system('cp', $archive, "$cwd/$file") == 0 or die;
			my @err = extract_files(
				[ { path => $cwd, file => $file } ], 1);
			is_deeply(\@err, [], "$file extracts");
			ok(!-e "$cwd/$file",
			   "$file is deleted after extraction");
			}
		ok(!-e "$case/outside/pwned", 'nothing is written outside');
		if ($overwrite) {
			is(read_file("$cwd/s/pwned"), 'pwned',
			   'second archive replaces the symlink');
			}
		else {
			is(readlink("$cwd/link/s"), '../outside',
			   'first archive gets its own directory');
			is(read_file("$cwd/through/s/pwned"), 'pwned',
			   'second archive gets its own directory');
			}
		is_deeply([ leftovers($cwd) ], [],
			  'private directory is removed');
		}
	is(getcwd(), $start, 'current directory is restored');
	};

subtest 'single-file uploads' => sub {
	our ($cwd, %in);
	local *main::check_allowed_path = sub {};
	local *main::validate_filename_path = sub { "$cwd/$_[0]" };
	local *main::unlink_file = sub { unlink($_[0]) };
	for my $ext ('gz', 'xz') {
		my $tool = $ext eq 'gz' ? 'gzip' : 'xz';
		my $bin = `command -v $tool 2>/dev/null`;
		chomp($bin);
		SKIP: {
		skip "$tool unavailable", 1 unless $bin;
		subtest $tool => sub {
			local *main::has_command = sub { $_[0] eq $tool ? $bin : undef };
			local *main::mimetype = sub { $ext eq 'gz' ? 'application/gzip' : 'application/x-xz' };
			local $cwd = "$task/stream-$ext";
			make_path($cwd);
			my $name = "daily report.$ext";
			my $src = "$cwd/daily report";
			write_file($src, 'saved contents');
			for my $overwrite (0, 1) {
				system(quotemeta($bin)." -c <".quotemeta($src)." >".quotemeta("$cwd/$name")) == 0 or die;
				write_file($src, 'existing');
				local %in = (overwrite_existing => $overwrite);
				my @err = extract_files([ { path => $cwd, file => $name } ], 1);
				is_deeply(\@err, [], 'decompression succeeds');
				is(read_file($overwrite ? $src : "$src(1)/daily report"),
				   'saved contents', 'output in selected destination');
				ok(!-e "$cwd/$name", 'successful upload removes archive');
				if (!$overwrite) {
					is(read_file($src), 'existing', 'existing file preserved');
					write_file($src, 'saved contents');
					}
				}
			};
		}
		}
	};

my $theme = $ENV{'AUTHENTIC_THEME_SOURCE'} ||
	"$root/../authentic-theme-src";
SKIP: {
	skip 'Authentic theme source is not available', 1
		if (!-f "$theme/extensions/file-manager/extract.cgi");
	subtest 'theme extraction' => sub {
		# Stub the theme library; this tests extraction only.
		our ($cwd, $path, %in, $name, %errors);
		local (*main::get_entries_list,
		       *main::fm_checked_cwd_path_or_error,
		       *main::fm_path_is_allowed, *main::mimetype,
		       *main::has_command, *main::redirect_local,
		       *main::urlize, *main::get_errors, *main::extra_query,
		       *main::unlink_file, *main::file_name_extension_splitter);
		*main::get_entries_list = sub { ($name) };
		*main::fm_checked_cwd_path_or_error = sub { "$cwd/$_[0]" };
		*main::fm_path_is_allowed = sub { 1 };
		*main::mimetype = sub { 'application/x-tar' };
		*main::has_command = sub { $_[0] eq 'tar' ? $tar : undef };
		*main::redirect_local = sub { };
		*main::urlize = sub { $_[0] };
		*main::get_errors = sub { %errors = %{$_[0]}; '' };
		*main::extra_query = sub { '' };
		*main::unlink_file = sub { unlink(@_) };
		*main::file_name_extension_splitter =
			sub { $_[0] =~ /^(.*)\.([^.]+)$/ };
		my $lib = "$theme/extensions/file-manager/file-manager-lib.pl";
		local $INC{$lib} = 1;
		local $ENV{'THEME_ROOT'} = $theme;
		for my $overwrite (1, 0) {
			my $case = "$task/theme-$overwrite";
			make_path("$case/work", "$case/outside");
			$cwd = $path = "$case/work";
			for my $archive ($link_tar, $through_tar) {
				($name) = $archive =~ /([^\/]+)$/;
				system('cp', $archive, "$cwd/$name") == 0
					or die;
				%in = (overwrite_efiles =>
					$overwrite ? 'true' : 'false',
				       delete => 1);
				%errors = ();
				do "$theme/extensions/file-manager/extract.cgi";
				die $@ if ($@);
				is_deeply(\%errors, {}, "$name extracts");
				ok(!-e "$cwd/$name",
				   "$name is deleted after extraction");
				}
			ok(!-e "$case/outside/pwned",
			   'nothing is written outside');
			if ($overwrite) {
				is(read_file("$cwd/s/pwned"), 'pwned',
				   'second archive replaces the symlink');
				}
			else {
				is(read_file("$cwd/through/s/pwned"), 'pwned',
				   'second archive gets its own directory');
				}
			is_deeply([ leftovers($cwd) ], [],
				  'private directory is removed');
			}
		my $saved = make_tar('theme-mode', sub {
			make_path("$_[0]/team");
			chmod(0700, "$_[0]/team") or die $!;
			});
		$name = 'team.tar';
		$cwd = $path = "$task/theme-mode";
		make_path("$cwd/team");
		chmod(0755, "$cwd/team") or die $!;
		system('cp', $saved, "$cwd/$name") == 0 or die;
		%in = (overwrite_efiles => 'true');
		do "$theme/extensions/file-manager/extract.cgi";
		die $@ if ($@);
		is((stat("$cwd/team"))[2] & 0777, 0700, 'theme restores archived mode');

		for my $ext ('gz', 'xz') {
			my $tool = $ext eq 'gz' ? 'gzip' : 'xz';
			my $bin = qx(command -v $tool 2>/dev/null);
			chomp($bin);
			next unless $bin;
			local *main::mimetype = sub {
				$ext eq 'gz' ? 'application/gzip' : 'application/x-xz';
				};
			local *main::has_command = sub { $_[0] eq $tool ? $bin : undef };
			for my $overwrite (0, 1) {
				$cwd = $path = "$task/theme-stream-$ext-$overwrite";
				make_path($cwd);
				$name = "sample.$ext";
				write_file("$cwd/sample", 'saved contents');
				system(quotemeta($bin)." -c <".quotemeta("$cwd/sample").
				       " >".quotemeta("$cwd/$name")) == 0 or die;
				write_file("$cwd/sample", 'existing');
				%in = (overwrite_efiles => $overwrite ? 'true' : 'false',
				       delete => 1);
				do "$theme/extensions/file-manager/extract.cgi";
				die $@ if $@;
				is_deeply(\%errors, {}, "$name extracts");
				is(read_file($overwrite ? "$cwd/sample" : "$cwd/sample(1)/sample"),
				   'saved contents', 'theme uses selected destination');
				ok(!-e "$cwd/$name", 'theme removes successful archive');
				is(read_file("$cwd/sample"), 'existing', 'existing file kept')
					unless $overwrite;
				}
			}
		is(getcwd(), $start, 'current directory is restored');
		};
	}

subtest 'tree walker' => sub {
	my $case = "$task/walk";
	make_path("$case/a/b/c", "$case/outside/x");
	write_file("$case/a/f1", '1');
	write_file("$case/a/b/f2", '2');
	write_file("$case/a/b/c/f3", '3');
	symlink("$case/outside", "$case/a/linkdir") or die $!;
	# walk(depth) returns the names seen with their directories.
	my $walk = sub {
		my ($depth) = @_;
		my @seen;
		filemin_walk_tree("$case/a", $depth, sub {
			my ($name) = @_;
			my $dir = getcwd();
			$dir =~ s/^.*\/walk\///;
			push(@seen, "$dir/$name");
			});
		return [ sort @seen ];
		};
	is_deeply($walk->(0), [], 'depth 0 skips a directory');
	is_deeply($walk->(1), [ 'a/b', 'a/f1', 'a/linkdir' ],
		  'depth 1 sees direct entries');
	is_deeply($walk->(-1), [ 'a/b', 'a/b/c', 'a/b/c/f3', 'a/b/f2', 'a/f1',
				 'a/linkdir' ],
		  'all levels are seen, symlinked directories are not entered');
	my @file;
	filemin_walk_tree("$case/a/f1", 0, sub { push(@file, $_[0]) });
	is_deeply(\@file, [ "$case/a/f1" ], 'a file path is passed as is');
	is(getcwd(), $start, 'current directory is restored');
	};

done_testing();
