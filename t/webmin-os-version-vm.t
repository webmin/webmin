#!/usr/bin/perl
# Run on a Debian Webmin VM with WEBMIN_OS_VERSION_VM_TEST=1.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

plan skip_all => 'requires an explicitly enabled Debian Webmin VM'
	if (!$ENV{'WEBMIN_OS_VERSION_VM_TEST'} || $^O ne 'linux');

my $source = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
my ($installed) = grep { -f "$_/WebminCore.pm" }
	('/usr/share/webmin', '/usr/libexec/webmin');
plan skip_all => 'requires Webmin and /etc/debian_version'
	if (!$installed || !-r '/etc/debian_version');
my $tmp = tempdir('webmin-os-version-XXXXXX', TMPDIR => 1, CLEANUP => 1);
require "$source/t/test-lib.pl";
my $release = read_text('/etc/debian_version');
chomp($release);
plan skip_all => 'requires a numeric Debian point release'
	if ($release !~ /\A(\d+)\.\d+(?:\.\d+)*\z/);
my $major = $1;
my %base = (os_type => 'debian-linux', os_version => $major,
	   real_os_type => 'Debian Linux', real_os_version => $major);

# Use installed Webmin helpers with private configuration and cache files.
make_path("$tmp/config/webmin", "$tmp/var/webmin", "$tmp/root");
write_text("$tmp/config/config", "lang=en\ntempdir=$tmp/work\n" .
	join('', map { "$_=$base{$_}\n" } sort keys %base));
write_text("$tmp/config/miniserv.conf", "root=$installed\n");
write_text("$tmp/config/webmin.acl", "root: webmin\n");
write_text("$tmp/config/webmin/config", '');
@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR SERVER_ROOT LIBROOT SCRIPT_NAME REMOTE_USER)} =
	("$tmp/config", "$tmp/var", $installed, $installed,
	 '/webmin/test.cgi', 'root');
unshift(@INC, $installed, "$installed/vendor_perl");
chdir("$installed/webmin") or die "chdir: $!";
do "$source/webmin/webmin-lib.pl";
die $@ if ($@);
ok(defined(&detect_operating_system), 'loads the changed detection library');

our (%gconfig, $root_directory, $config_directory,
     $detect_operating_system_cache, $realos_cache_file,
     $webmin_yum_repo_file, $webmin_apt_repo_file, $global_apt_repo_file);
copy("$source/oschooser.pl", "$tmp/root/oschooser.pl") or die "copy: $!";
copy("$source/os_list.txt", "$tmp/root/os_list.txt") or die "copy: $!";
$root_directory = "$tmp/root";
$webmin_yum_repo_file = "$tmp/no-yum-repo";
$webmin_apt_repo_file = "$tmp/no-apt-repo";
$global_apt_repo_file = "$tmp/no-global-repo";
my $uptime = 172800;

# Isolate OS notifications from unrelated modules and remote update checks.
no warnings qw(redefine once);
local *get_system_uptime = sub { return $uptime; };
local *load_theme_library = sub { };
local *shared_root_directory = sub { return 0; };
local *foreign_available = sub { return $_[0] eq 'webmin'; };
local *foreign_check = sub { return 0; };
local *foreign_installed = sub { return 0; };
local *get_module_acl = sub { return (); };

# Real detection must retain the existing config versions and add the full one.
my %detected = detect_operating_system();
is($detected{'real_os_version_full'}, $release,
	'detection reads the installed Debian point release');
is($detected{'real_os_version'}, $major,
	'detection preserves the existing real OS version');
is($detected{'os_version'}, $major,
	'detection preserves module configuration matching');

# A new cache should be reused, while pre-field caches must be upgraded.
my %old_cache = (%base, time => time());
write_file($detect_operating_system_cache, \%old_cache);
my %migrated = detect_operating_system(undef, 1);
is($migrated{'real_os_version_full'}, $release,
	'fresh detection cache without the full version is rebuilt');
my %saved_cache;
read_file($detect_operating_system_cache, \%saved_cache);
is($saved_cache{'real_os_version_full'}, $release,
	'detection cache persists the full version');
my %cached = (%detected, real_os_version_full => "$major.999", time => time());
write_file($detect_operating_system_cache, \%cached);
my %reused = detect_operating_system(undef, 1);
is($reused{'real_os_version_full'}, "$major.999",
	'complete fresh detection cache is reused');

# Both cache layers must migrate before the dashboard reads the saved field.
write_file($detect_operating_system_cache, \%old_cache);
write_file($realos_cache_file, \%old_cache);
my @notifs = get_webmin_notifications(1);
is($gconfig{'real_os_version_full'}, $release,
	'notification refresh fills the missing global field');
is_deeply([@gconfig{sort keys %base}], [@base{sort keys %base}],
	'full-version migration preserves all existing OS fields');
my %saved;
read_file("$config_directory/config", \%saved);
is($saved{'real_os_version_full'}, $release,
	'full version is written to the global config');
is(scalar(@notifs), 0, 'a display-only change does not prompt for an OS upgrade');
{
	# Repeated page loads must not rewrite the unchanged global configuration.
	my $writer = \&write_file;
	my $writes = 0;
	local *write_file = sub {
		$writes++ if ($_[0] eq "$config_directory/config");
		return $writer->(@_);
		};
	get_webmin_notifications(1);
	is($writes, 0, 'unchanged full version does not rewrite the config');
}

# Expiry and reboot must refresh both caches after a point-release update.
foreach my $case ([ 'daily expiry', 172800, 90000 ],
		 [ 'reboot', 60, 3600 ]) {
	my ($name, $seconds_up, $cache_age) = @$case;
	$uptime = $seconds_up;
	my $then = time() - $cache_age;
	my %stale = (%base, real_os_version_full => "$major.0", time => $then);
	$gconfig{'real_os_version_full'} = "$major.0";
	write_file($detect_operating_system_cache, \%stale);
	write_file($realos_cache_file, \%stale);
	utime($then, $then, $realos_cache_file) or die "utime: $!";
	my @messages = get_webmin_notifications(1);
	is($gconfig{'real_os_version_full'}, $release,
		"$name refreshes the saved point release");
	is(scalar(@messages), 0, "$name does not prompt for a point release");
	read_file("$config_directory/config", \%saved);
	is($saved{'real_os_version_full'}, $release,
		"$name persists the refreshed full version");
}

# A detected major upgrade must not relabel an unconfirmed configuration.
{
	local %gconfig = (%gconfig, real_os_version => $major - 1,
		os_version => $major - 1, real_os_version_full => ($major - 1).'.9');
	my @messages = get_webmin_notifications(1);
	is($gconfig{'real_os_version_full'}, ($major - 1).'.9',
		'unconfirmed major upgrade keeps the previous full version');
	like(join('', @messages), qr/fix_os\.cgi/,
		'major upgrade still requires the existing confirmation');
}

# Applying detected settings must also pass the field to Usermin.
{
	my %usermin = (%base, real_os_version_full => "$major.0");
	local *foreign_installed = sub { return $_[0] eq 'usermin'; };
	local *foreign_require = sub { };
	local $usermin::usermin_config = "$tmp/usermin-config";
	local *usermin::get_usermin_miniserv_config = sub { };
	local *usermin::get_usermin_config = sub { %{$_[0]} = %usermin; };
	local *usermin::put_usermin_config = sub {
		%usermin = %{$_[0]};
		write_file($usermin::usermin_config, \%usermin);
		};
	apply_new_os_version(\%detected);
	is($gconfig{'real_os_version_full'}, $release,
		'applying detected settings stores the full version in Webmin');
	is($usermin{'real_os_version_full'}, $release,
		'applying detected settings synchronizes the full version to Usermin');
	apply_new_os_version(\%base);
	is($gconfig{'real_os_version_full'}, $major,
		'older detection data cannot leave a stale Webmin full version');
	is($usermin{'real_os_version_full'}, $major,
		'older detection data cannot leave a stale Usermin full version');
}

# Other distributions and mismatched Debian releases use their detected version.
foreach my $case ([ 'Ubuntu Linux', '24.04', 'debian-linux' ],
		 [ 'Debian Linux', $major + 1, 'debian-linux' ],
		 [ 'Rocky Linux', '9.8', 'redhat-linux' ],
		 [ 'AlmaLinux', '10.3', 'redhat-linux' ]) {
	my ($type, $version, $internal) = @$case;
	write_text("$tmp/os-list", "$type\t$version\t$internal\t$version\t1\n");
	my %os = detect_operating_system("$tmp/os-list");
	is($os{'real_os_version_full'}, $version,
		"$type $version does not borrow the host Debian point release");
}

# Full-version detection must not depend on the display name.
write_text("$tmp/os-list",
	"Debian GNU/Linux\t$major\tdebian-linux\t$major\t1\n");
my %renamed = detect_operating_system("$tmp/os-list");
is($renamed{'real_os_version_full'}, $release,
	'full version uses OS identity rather than the display name');

# Exercise the real Rocky and AlmaLinux rules with isolated release files.
make_path("$tmp/releases");
my $redhat_rules = join("\n", grep { /^(Rocky Linux|AlmaLinux)\t/ }
	split(/\n/, read_text("$source/os_list.txt"))) . "\n";
$redhat_rules =~ s{/etc/}{$tmp/releases/}g;
write_text("$tmp/redhat-os-list", $redhat_rules);
foreach my $distro ([ 'Rocky Linux', 'rocky' ], [ 'AlmaLinux', 'almalinux' ]) {
	foreach my $version ('9.8', '10.3') {
		foreach my $fallback (0, 1) {
			# Each case has either its own release file or the Red Hat fallback.
			unlink("$tmp/releases/$_-release")
				foreach ('rocky', 'almalinux', 'redhat');
			my $file = $fallback ? 'redhat' : $distro->[1];
			write_text("$tmp/releases/$file-release",
				"$distro->[0] release $version (Test)\n");
			my %os = detect_operating_system("$tmp/redhat-os-list");
			is_deeply({ map { $_ => $os{$_} } keys %base,
						       'real_os_version_full' },
				{ real_os_type => $distro->[0],
				  os_type => 'redhat-linux', os_version => $version + 8,
				  real_os_version => $version,
				  real_os_version_full => $version },
				"$distro->[0] $version keeps point and config versions from $file-release");
		}
	}
}

# The settings pages must update or reset the field along with OS selections.
{
	our (%in, %access, %uconfig, $usermin_config, $usermin_miniserv_config);
	local $INC{'./webmin-lib.pl'} = 1;
	local $INC{'./usermin-lib.pl'} = 1;
	local $ENV{'MINISERV_CONFIG'} = "$tmp/settings-miniserv";
	local $usermin_config = "$tmp/usermin-settings";
	local $usermin_miniserv_config = "$tmp/usermin-miniserv";
	local %access = (os => 1);
	local *ReadParse = sub { };
	local *get_miniserv_config = sub { %{$_[0]} = (); };
	local *put_miniserv_config = sub { };
	local *show_restart_page = sub { };
	local *webmin_log = sub { };
	local *redirect = sub { };
	local *restart_usermin_miniserv = sub { };
	local *get_usermin_config = sub { };
	local *get_usermin_miniserv_config = sub {
		%{$_[0]} = (root => "$tmp/root");
		};
	local *put_usermin_config = sub {
		write_file($usermin_config, $_[0]);
		};
	local *put_usermin_miniserv_config = sub { };
	local *list_operating_systems = sub { return (); };
	local *webmin::list_operating_systems = \&list_operating_systems;
	local *webmin::detect_operating_system = \&detect_operating_system;
	foreach my $module ('webmin', 'usermin') {
		foreach my $mode ('automatic', 'manual', 'unchanged') {
			local %gconfig = (%gconfig, %base, real_os_version_full => $release);
			local %uconfig = %gconfig;
			my $version = $mode eq 'manual' ? $major - 1 : $major;
			local %in = (update => $mode eq 'automatic',
				type => 'Debian Linux', version => $version,
				itype => 'debian-linux', iversion => $version);
			do "$source/$module/change_os.cgi";
			die $@ if ($@);
			my %stored;
			read_file($module eq 'webmin' ? "$config_directory/config" :
				  $usermin_config, \%stored);
			is($stored{'real_os_version_full'},
				$mode eq 'manual' ? $version : $release,
				"$module $mode settings keep the full version consistent");
		}
	}
}

done_testing();
