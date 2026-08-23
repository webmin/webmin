#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

our (%config, %packages, %text);
our ($yum_command, $supports_dnf_versionlock, $dnf_version);

sub has_command
{
return $_[0] eq 'dnf' ? '/usr/bin/dnf' : undef;
}

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";

do './software/yum-lib.pl' or die $@ || $!;

{
no warnings qw(once redefine);
local *clean_language = sub { };
local *reset_environment = sub { };
local *backquote_command = sub {
	return $_[0] =~ /--version/ ? "4.14.0\n" :
		"  versionlock        control package version locks\n";
	};
local $dnf_version;
local $supports_dnf_versionlock;
is(get_dnf_version(), 4, 'detects DNF 4');
ok(supports_update_system_holds(),
	'detects the DNF 4 versionlock command');
is(update_system_hold_flags(), '--disableplugin=versionlock',
	'uses the DNF 4 held-update discovery option');
}

{
no warnings qw(once redefine);
local *clean_language = sub { };
local *reset_environment = sub { };
local *backquote_command = sub {
	return $_[0] =~ /--version/ ? "dnf5 version 5.4.2.1\n" :
		"  versionlock        Manage versionlock configuration\n";
	};
local $dnf_version;
local $supports_dnf_versionlock;
is(get_dnf_version(), 5, 'detects DNF 5');
ok(supports_update_system_holds(),
	'detects the DNF 5 versionlock command');
is(update_system_hold_flags(), '--setopt=disable_excludes=*',
	'uses the DNF 5 held-update discovery option');
}

{
no warnings qw(once redefine);
local *clean_language = sub { };
local *reset_environment = sub { };
local *backquote_command = sub {
	return $_[0] =~ /--version/ ? "4.14.0\n" :
		"No such command: versionlock\n";
	};
local $dnf_version;
local $supports_dnf_versionlock;
ok(!supports_update_system_holds(),
	'hides holds when DNF does not expose versionlock');
}

{
no warnings qw(once redefine);
my $output =
	"bash-0:5.1.8-8.el9.*\n".
	"python3-*\n".
	"0:python3-pip-21.2.3-8.el9.*\n".
	"!blocked-0:2.0-1.el9.*\n";
local *supports_update_system_holds = sub { return 1; };
local *get_dnf_version = sub { return 4; };
local *clean_language = sub { };
local *reset_environment = sub { };
local *open_execute_command = sub {
	my ($fh) = @_;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$output)
		or die "open simulated DNF 4 locks: $!";
	};

is_deeply([ list_update_system_holds() ], [ qw(bash python3-pip) ],
	'lists DNF 4 exact locks without raw patterns or excludes');
}

{
no warnings qw(once redefine);
my $output =
	"# Added by 'dnf versionlock add nano'\n".
	"Package name: nano\n".
	"evr = 8.7.1-2.fc44\n\n".
	"Package name: coreutils\n".
	"evr != 9.10-4.fc44\n\n".
	"Package name: bash\n".
	"evr = 5.3.0-2.fc44\n".
	"arch = aarch64\n\n".
	"Package name: python3-*\n".
	"evr = 3.14.0-1.fc44\n\n".
	"Package name: nano\n".
	"evr > 9\n";
local *supports_update_system_holds = sub { return 1; };
local *get_dnf_version = sub { return 5; };
local *clean_language = sub { };
local *reset_environment = sub { };
local *open_execute_command = sub {
	my ($fh) = @_;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$output)
		or die "open simulated DNF 5 locks: $!";
	};

is_deeply([ list_update_system_holds() ], [ ],
	'skips DNF 5 names with duplicate, custom or glob lock rules');

$output = "Package name: nano\nevr = 8.7.1-2.fc44\n";
is_deeply([ list_update_system_holds() ], [ 'nano' ],
	'lists a simple DNF 5 exact lock by package name');
}

{
no warnings qw(once redefine);
is(update_system_hold_spec_name('bash-0:5.1.8-8.el9.*'), 'bash',
	'decodes DNF 4 name-epoch-version entries');
is(update_system_hold_spec_name('0:python3-pip-21.2.3-8.el9.*'),
	'python3-pip', 'decodes legacy DNF 4 epoch-name entries');
is(update_system_hold_spec_name('python3-*'), undef,
	'does not treat a raw pattern as an exact lock');
is(update_system_hold_spec_name('!bash-0:5.1.8-8.el9.*'), undef,
	'does not treat an exclude as an exact lock');
is(update_system_nevra_name('nano-0:8.7.1-2.fc44'), 'nano',
	'extracts a DNF 5 package name from transaction output');
is(update_system_nevra_name(
	'webmin-virtualmin-support-2:4.3.202602061237-1.noarch'),
	'webmin-virtualmin-support', 'extracts a hyphenated NEVRA name');
is(update_system_nevra_name('nano-8.7.1-2.fc44.aarch64'), 'nano',
	'extracts a package name when no epoch is printed');
}

{
no warnings qw(once redefine);
my @commands;
local *supports_update_system_holds = sub { return 1; };
local *unique = sub {
	my %seen;
	return grep { !$seen{$_}++ } @_;
	};
local *clean_language = sub { };
local *reset_environment = sub { };
local *trim = sub {
	my ($value) = @_;
	$value =~ s/^\s+|\s+$//g;
	return $value;
	};
local *list_update_system_holds = sub { return ('bash'); };
local *execute_command_logged = sub {
	my ($command, undef, $stdout) = @_;
	push(@commands, $command);
	$$stdout = '';
	return 0;
	};

is(update_system_hold([ 'bash', 'bash', 'coreutils' ], 1), undef,
	'adds DNF version locks successfully');
is(update_system_hold([ 'bash', 'coreutils' ], 0), undef,
	'removes only package names reported as exactly locked');
is_deeply(\@commands,
	[ '/usr/bin/dnf -q versionlock add bash',
	  '/usr/bin/dnf -q versionlock add coreutils',
	  '/usr/bin/dnf -q versionlock delete bash' ],
	'uses name-based add and delete commands on both DNF generations');
}

{
no warnings qw(once redefine);
my $dnf_output =
	"[3/6] Upgrading bash-0:5.3.0-2.fc44 100% | 1.0 MiB/s | 1.0 MiB | 00m01s\n";
my $executed_command;
my @lock_actions;
local *update_system_hold_flags = sub { return 'held-update'; };
local *append_architectures = sub { return @_; };
local *package_info = sub { return ('bash'); };
local *update_system_repo = sub { return undef; };
local *additional_log = sub { };
local *html_escape = sub { return $_[0]; };
local *text = sub { return $_[0]; };
local *unique = sub {
	my %seen;
	return grep { !$seen{$_}++ } @_;
	};
local *delete_update_system_holds = sub {
	my ($packages, $removed) = @_;
	push(@lock_actions, [ 'delete', [ @$packages ] ]);
	push(@$removed, 'bash');
	return undef;
	};
local *restore_update_system_holds = sub {
	my ($packages) = @_;
	push(@lock_actions, [ 'restore', [ @$packages ] ]);
	return undef;
	};
local *open_execute_command = sub {
	my ($fh, $command) = @_;
	$executed_command = $command;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$dnf_output)
		or die "open simulated DNF install: $!";
	};

my $printed = '';
open(my $stdout, '>', \$printed) or die "open captured stdout: $!";
local *STDOUT = $stdout;
$? = 0;
my @installed = update_system_install('bash', { }, 1, 'held-update');
is_deeply(\@installed, [ 'bash' ],
	'returns a DNF 5 package updated while held');
unlike($executed_command, qr/held-update|disableplugin|disable_excludes/,
	'runs the transaction without a global versionlock bypass');
is_deeply(\@lock_actions,
	[ [ 'delete', [ 'bash' ] ], [ 'restore', [ 'bash' ] ] ],
	'temporarily unlocks and then re-locks only the selected package');
}

{
no warnings qw(once redefine);
my $dnf_output =
	"bash.aarch64 5.1.8-10.el9 baseos\n".
	"coreutils.aarch64 8.32-40.el9 baseos\n";
my @commands;
local *supports_update_system_holds = sub { return 1; };
local *list_update_system_holds = sub { return ('bash'); };
local *set_yum_security_field = sub { };
local *get_dnf_version = sub { return 4; };
local *open_execute_command = sub {
	my ($fh, $command) = @_;
	push(@commands, $command);
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$dnf_output)
		or die "open simulated DNF updates: $!";
	};

my @normal = update_system_updates(0);
is_deeply([ map { $_->{'name'} } @normal ], [ 'coreutils' ],
	'DNF 4 regular updates exclude held packages');
my @with_holds = update_system_updates(1);
is_deeply([ map { $_->{'name'} } @with_holds ],
	[ 'bash', 'coreutils' ], 'DNF 4 held-update query includes locks');
like($commands[1], qr/--disableplugin=versionlock check-update/,
	'DNF 4 uses its plugin bypass for held-update discovery');

@commands = ( );
local *get_dnf_version = sub { return 5; };
@with_holds = update_system_updates(1);
like($commands[0], qr/--setopt=disable_excludes=\\\* check-update/,
	'DNF 5 disables excludes for held-update discovery');
ok($with_holds[0]->{'held'}, 'marks a DNF 5 locked update as held');
}

{
no warnings qw(once redefine);
my $dnf_output =
	"Last metadata expiration check: 0:10:00 ago.\n".
	"Dependencies resolved.\n".
	"================================================================\n".
	" Package                  Architecture Version        Repository Size\n".
	"================================================================\n".
	"Upgrading:\n".
	" tzdata                   noarch       2026c-1.fc44   updates    497 k\n".
	" vim-minimal              aarch64      2:9.1.2000-2.fc44 updates 647 k\n".
	"Installing dependencies:\n".
	" wbt-virtual-server-theme\n".
	"                          noarch       21.20-1        virtualmin 2.5 M\n".
	"Removing dependent packages:\n".
	" oldpkg                   noarch       1.0-1          system     1 k\n".
	"\nTransaction Summary:\n".
	"Upgrade  2 Packages\n";
my $command;
my @lock_actions;
my $dnf_major = 4;
local *update_system_hold_flags = sub {
	return '--setopt=disable_excludes=*';
	};
local *get_dnf_version = sub { return $dnf_major; };
local *open_execute_command = sub {
	my ($fh, $cmd) = @_;
	$command = $cmd;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$dnf_output)
		or die "open simulated DNF transaction: $!";
	};
local *clean_language = sub { };
local *reset_environment = sub { };
local *trim = sub {
	my ($value) = @_;
	$value =~ s/^\s+|\s+$//g;
	return $value;
	};
local *unique = sub {
	my %seen;
	return grep { !$seen{$_}++ } @_;
	};
local *delete_update_system_holds = sub {
	my ($packages, $removed) = @_;
	push(@lock_actions, [ 'delete', [ @$packages ] ]);
	push(@$removed, @$packages);
	return undef;
	};
local *restore_update_system_holds = sub {
	my ($packages) = @_;
	push(@lock_actions, [ 'restore', [ @$packages ] ]);
	return undef;
	};

my @ops = update_system_operations('tzdata vim-minimal');
like($command, qr{^/usr/bin/dnf --assumeno install },
	'uses a simulated install for DNF 4 operations');
unlike($command, qr/disableplugin|disable_excludes/,
	'keeps versionlock active for regular operations');
is_deeply([ map { $_->{'name'} } @ops ],
	[ qw(tzdata vim-minimal wbt-virtual-server-theme) ],
	'parses install and upgrade rows from a DNF transaction table');

$dnf_major = 5;
@ops = update_system_operations('tzdata vim-minimal',
	'--setopt=disable_excludes=*');
like($command, qr{^/usr/bin/dnf --assumeno upgrade },
	'uses a simulated upgrade for installed packages on DNF 5');
unlike($command, qr/disableplugin|disable_excludes/,
	'does not pass the discovery-only bypass to a transaction preview');
is_deeply(\@lock_actions,
	[ [ 'delete', [ qw(tzdata vim-minimal) ] ],
	  [ 'restore', [ qw(tzdata vim-minimal) ] ] ],
	'temporarily unlocks selected packages for a held-update preview');
is_deeply([ map { $_->{'name'} } @ops ],
	[ qw(tzdata vim-minimal wbt-virtual-server-theme) ],
	'parses the held-package preview after restoring its locks');
is($ops[1]->{'epoch'}, '2', 'splits epochs from preview versions');
is($ops[2]->{'arch'}, 'noarch', 'handles wrapped package names');
}

done_testing();
