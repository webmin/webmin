#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

# Build an isolated openSUSE-style /etc and /usr/etc configuration layout.
my $module_dir = abs_path(dirname(abs_path($0))."/..");
my $root_dir = abs_path("$module_dir/..");
my $config_dir = tempdir(CLEANUP => 1);
my $var_dir = tempdir(CLEANUP => 1);
my $fixture_dir = tempdir(CLEANUP => 1);
my $local_add_dir = "$fixture_dir/etc/logrotate.d";
my $vendor_add_dir = "$fixture_dir/usr/etc/logrotate.d";
my $local_main_file = "$fixture_dir/etc/logrotate.conf";
my $vendor_main_file = "$fixture_dir/usr/etc/logrotate.conf";
my $wrapper = "$fixture_dir/usr/sbin/logrotate-all";
make_path("$config_dir/logrotate", $local_add_dir,
	  "$local_add_dir/nested", "$vendor_add_dir/deep",
	  "$vendor_add_dir/nested", dirname($wrapper));

# write_text(file, contents)
# Writes a text fixture and fails the test immediately on an I/O error
sub write_text
{
my ($file, $text) = @_;
open(my $fh, ">", $file) or die "open $file: $!";
print $fh $text;
close($fh) or die "close $file: $!";
}

# read_text(file)
# Returns the complete contents of a text fixture
sub read_text
{
my ($file) = @_;
open(my $fh, "<", $file) or die "open $file: $!";
local $/;
my $text = <$fh>;
close($fh) or die "close $file: $!";
return $text;
}

# Populate both trees with vendor-only, local-only, nested, and overridden
# files so the fixture exercises the wrapper's key overlay rules.
my $vendor_main_text =
	"weekly\n/var/log/vendor-main.log {\n\trotate 4\n}\n";
write_text("$config_dir/config", "os_type=linux\nos_version=0\n");
write_text("$config_dir/logrotate/config",
	"sort_mode=0\n".
	"logrotate_conf=$local_main_file\n".
	"vendor_logrotate_conf=$vendor_main_file\n".
	"add_file=$local_add_dir\n".
	"vendor_add_file=$vendor_add_dir\n".
	"scan_add_file=1\n".
	"logrotate=/bin/echo\n".
	"logrotate_all=$wrapper\n");
write_text($vendor_main_file, $vendor_main_text);
write_text("$vendor_add_dir/one", "/var/log/vendor-one.log {\n\tdaily\n}\n");
write_text("$vendor_add_dir/shared",
	"/var/log/vendor-shared.log {\n\tdaily\n}\n");
write_text("$vendor_add_dir/deep/vendor",
	"/var/log/deep-vendor.log {\n\tmonthly\n}\n");
write_text("$local_add_dir/local-only",
	"/var/log/local-only.log {\n\tweekly\n}\n");
write_text("$local_add_dir/shared",
	"/var/log/local-shared.log {\n\tweekly\n}\n");
write_text("$local_add_dir/nested/local",
	"/var/log/nested-local.log {\n\tweekly\n}\n");
write_text($wrapper, "#!/bin/sh\nexit 0\n");
chmod(0755, $wrapper) or die "chmod $wrapper: $!";

# Point Webmin at the isolated fixture before loading the module library.
$ENV{'WEBMIN_CONFIG'} = $config_dir;
$ENV{'WEBMIN_VAR'} = $var_dir;
$ENV{'FOREIGN_MODULE_NAME'} = 'logrotate';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root_dir;
chdir($module_dir) or die "chdir $module_dir: $!";
require "$module_dir/logrotate-lib.pl";

# clear_config_cache()
# Forces each test phase to parse the configuration from disk again
sub clear_config_cache
{
no warnings 'once';
%main::get_config_cache = ( );
%main::get_config_lnum_cache = ( );
%main::get_config_files_cache = ( );
$main::get_config_parent_cache = undef;
}

# log_names(config)
# Returns only the log path names from parsed rotation sections
sub log_names
{
my ($config) = @_;
return [ map { $_->{'name'}->[0] }
	 grep { $_->{'members'} } @$config ];
}

# The vendor main file is the initial fallback because no local main exists.
is(main::get_main_config_file(), $vendor_main_file,
	'vendor main config is used when no local main config exists');
ok(main::is_vendor_main_config($vendor_main_file),
	'vendor main config is recognized');

# Match the wrapper's existence test rather than requiring a regular file.
my $nonregular_main = "$fixture_dir/etc/nonregular-main";
make_path($nonregular_main);
{
local $main::config{'logrotate_conf'} = $nonregular_main;
is(main::get_main_config_file(), $nonregular_main,
	'local main path wins whenever it exists');
}
{
local $main::config{'logrotate_conf'} = "$fixture_dir/etc/missing-main";
local $main::config{'vendor_logrotate_conf'} =
	"$fixture_dir/usr/etc/missing-main";
is(main::get_main_config_file(), $main::config{'vendor_logrotate_conf'},
	'configured vendor main path is used whenever the local path is absent');
}

# The effective list is sorted by relative path, with local files replacing
# vendor files that have the same relative path.
my @effective_add_files = (
	"$vendor_add_dir/deep/vendor",
	"$local_add_dir/local-only",
	"$local_add_dir/nested/local",
	"$vendor_add_dir/one",
	"$local_add_dir/shared",
	);
my ($config, undef, $files) = main::get_config();
is_deeply(log_names($config),
	[ '/var/log/vendor-main.log', '/var/log/deep-vendor.log',
	  '/var/log/local-only.log', '/var/log/nested-local.log',
	  '/var/log/vendor-one.log', '/var/log/local-shared.log' ],
	'vendor and local trees are recursively merged with local precedence');
is_deeply([ map { $_->{'index'} } grep { $_->{'members'} } @$config ],
	[ 1, 2, 3, 4, 5, 6 ],
	'effective sections keep stable top-level indexes');
is_deeply($files, [ $vendor_main_file, @effective_add_files ],
	'file cache contains the effective main and merged drop-ins');
ok(!grep({ $_ eq "$vendor_add_dir/shared" } @$files),
	'local file hides the same relative vendor file');

my (undef, undef, $primary_files) = main::get_config($vendor_main_file);
is_deeply([ main::get_add_file_configs($primary_files) ],
	\@effective_add_files,
	'externally loaded configuration files match the effective overlay');
is(main::get_scheduled_logrotate_command(), main::quote_path($wrapper),
	'scheduled rotations use the distribution wrapper');

# Disabling the opt-in must restore the behavior used by other distributions.
$main::config{'scan_add_file'} = 0;
clear_config_cache();
($config, undef, $files) = main::get_config();
is_deeply(log_names($config), [ '/var/log/vendor-main.log' ],
	'vendor and local trees are not scanned without explicit opt-in');
is_deeply($files, [ $vendor_main_file ],
	'file cache excludes external directories when scanning is disabled');

# The low-level writer must fail closed if a caller skips copy-on-write.
{
no warnings qw(once redefine);
local *main::error = sub { die $_[0]; };
eval {
	main::save_directive(main::get_config_parent(), 'weekly', '');
	};
like($@, qr/Refusing to modify vendor configuration/,
	'direct writes to vendor configuration are rejected');
}

# Editing global options materializes an exact local copy of the vendor main.
$main::config{'scan_add_file'} = 1;
clear_config_cache();
is(main::ensure_local_main_config(), $local_main_file,
	'editing the vendor main config creates a local main config');
is(read_text($local_main_file), $vendor_main_text,
	'local main config starts as an exact vendor copy');
is(read_text($vendor_main_file), $vendor_main_text,
	'copying the main config does not alter the vendor file');
is(main::get_main_config_file(), $local_main_file,
	'local main config takes precedence after it is created');

# Editing a nested vendor drop-in copies the whole source file to the same
# relative path in the local tree and immediately switches parser ownership.
my $vendor_dropin = "$vendor_add_dir/deep/vendor";
my $local_dropin = "$local_add_dir/deep/vendor";
is(main::ensure_local_config_override($vendor_dropin), $local_dropin,
	'editing a vendor drop-in creates its matching local override');
is(read_text($local_dropin), read_text($vendor_dropin),
	'local drop-in starts as an exact copy of the whole vendor file');
is(main::get_local_override_file($vendor_dropin), $local_dropin,
	'vendor drop-in maps to the correct writable path');
is(main::get_vendor_config_file($local_dropin), $vendor_dropin,
	'local override maps back to the shadowed vendor file');

($config, undef, $files) = main::get_config();
my ($deep_log) = grep { $_->{'members'} &&
			       $_->{'name'}->[0] eq '/var/log/deep-vendor.log' }
			 @$config;
is($deep_log->{'file'}, $local_dropin,
	'parser switches to the local copy after an override is created');

# An empty local file must remain both effective and backup-visible because
# its existence is what prevents the vendor file from becoming active again.
write_text($local_dropin, '');
clear_config_cache();
main::delete_if_empty($local_dropin);
ok(-e $local_dropin,
	'empty local override is retained so the vendor file stays disabled');
(undef, undef, $files) = main::get_config();
ok(grep({ $_ eq $local_dropin } @$files),
	'empty local override remains in the effective file cache for backups');
ok(!grep({ $_ eq $vendor_dropin } @$files),
	'empty local override continues to hide the vendor file');

# Explicit includes and external discovery must not parse the same file twice.
write_text($local_main_file,
	"weekly\ninclude $local_add_dir\n".
	"/var/log/main.log {\n\trotate 4\n}\n");
clear_config_cache();
($config, undef, $files) = main::get_config();
is(scalar(grep { $_->{'members'} &&
			 $_->{'name'}->[0] eq '/var/log/local-only.log' }
		 @$config), 1,
	'explicitly included files are not parsed a second time');
is(scalar(grep { main::same_file($_, "$local_add_dir/local-only") }
		 @$files), 1,
	'explicit include is represented once in the file cache');

# A local path selected by the wrapper's existence check wins even when find
# discovers the relative name only from the regular vendor file.
my $edge_dir = tempdir(CLEANUP => 1);
my $edge_local_dir = "$edge_dir/etc/logrotate.d";
my $edge_vendor_dir = "$edge_dir/usr/etc/logrotate.d";
my $edge_target = "$edge_dir/local-target";
make_path($edge_local_dir, $edge_vendor_dir);
write_text("$edge_vendor_dir/linked", "vendor\n");
write_text($edge_target, "local\n");
symlink($edge_target, "$edge_local_dir/linked") or
	die "symlink $edge_local_dir/linked: $!";
{
local $main::config{'add_file'} = $edge_local_dir;
local $main::config{'vendor_add_file'} = $edge_vendor_dir;
is_deeply([ main::get_add_file_configs() ], [ "$edge_local_dir/linked" ],
	'local existing path overrides the matching vendor file');
}

done_testing();
