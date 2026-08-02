#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $module_dir = abs_path(dirname(abs_path($0))."/..");
my $root_dir = abs_path("$module_dir/..");
my $config_dir = tempdir(CLEANUP => 1);
my $var_dir = tempdir(CLEANUP => 1);
my $fixture_dir = tempdir(CLEANUP => 1);
my $add_dir = "$fixture_dir/logrotate.d";
my $main_file = "$fixture_dir/logrotate.conf";
make_path("$config_dir/logrotate", $add_dir);

sub write_text
{
my ($file, $text) = @_;
open(my $fh, ">", $file) or die "open $file: $!";
print $fh $text;
close($fh) or die "close $file: $!";
}

write_text("$config_dir/config", "os_type=linux\nos_version=0\n");
write_text("$config_dir/logrotate/config",
	"sort_mode=0\n".
	"logrotate_conf=$main_file\n".
	"add_file=$add_dir\n".
	"scan_add_file=1\n".
	"logrotate=logrotate\n");
write_text($main_file, "weekly\n/var/log/main.log {\n\trotate 4\n}\n");
write_text("$add_dir/one", "/var/log/one.log {\n\tdaily\n}\n");
write_text("$add_dir/two", "/var/log/two.log {\n\tmonthly\n}\n");

$ENV{'WEBMIN_CONFIG'} = $config_dir;
$ENV{'WEBMIN_VAR'} = $var_dir;
$ENV{'FOREIGN_MODULE_NAME'} = 'logrotate';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root_dir;
chdir($module_dir) or die "chdir $module_dir: $!";
require "$module_dir/logrotate-lib.pl";

sub clear_config_cache
{
no warnings 'once';
%main::get_config_cache = ( );
%main::get_config_lnum_cache = ( );
%main::get_config_files_cache = ( );
$main::get_config_parent_cache = undef;
}

sub log_names
{
my ($config) = @_;
return [ map { $_->{'name'}->[0] }
	 grep { $_->{'members'} } @$config ];
}

my ($config, undef, $files) = main::get_config();
is_deeply(log_names($config),
	[ '/var/log/main.log', '/var/log/one.log', '/var/log/two.log' ],
	'opt-in scan loads sections from add_file directory');
is_deeply([ map { $_->{'index'} } grep { $_->{'members'} } @$config ],
	[ 1, 2, 3 ], 'scanned sections keep stable top-level indexes');
is_deeply($files,
	[ $main_file, "$add_dir/one", "$add_dir/two" ],
	'file cache contains the primary and scanned configuration files');
my (undef, undef, $primary_files) = main::get_config($main_file);
is_deeply([ main::get_add_file_configs($primary_files) ],
	[ "$add_dir/one", "$add_dir/two" ],
	'force rotation adds externally loaded configuration files');

$main::config{'scan_add_file'} = 0;
clear_config_cache();
($config, undef, $files) = main::get_config();
is_deeply(log_names($config), [ '/var/log/main.log' ],
	'add_file is not scanned without explicit opt-in');
is_deeply($files, [ $main_file ],
	'file cache excludes add_file directory when scanning is disabled');

$main::config{'scan_add_file'} = 1;
write_text($main_file,
	"weekly\ninclude $add_dir\n/var/log/main.log {\n\trotate 4\n}\n");
clear_config_cache();
($config, undef, $files) = main::get_config();
is_deeply(log_names($config),
	[ '/var/log/one.log', '/var/log/two.log', '/var/log/main.log' ],
	'explicitly included files are not loaded a second time');
is(scalar(grep { main::same_file($_, "$add_dir/one") } @$files), 1,
	'explicit include is represented once in the file cache');
(undef, undef, $primary_files) = main::get_config($main_file);
is_deeply([ main::get_add_file_configs($primary_files) ], [ ],
	'force rotation does not repeat explicitly included files');

done_testing();
