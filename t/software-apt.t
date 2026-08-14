#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

our %config;
our $apt_get_command;

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";

do './software/apt-lib.pl' or die $@ || $!;

is(strip_apt_package_arch('libtinfo6:amd64'), 'libtinfo6',
	'strips native Debian architecture suffix');
is(strip_apt_package_arch('libgomp1:i386'), 'libgomp1',
	'strips foreign Debian architecture suffix');
is(strip_apt_package_arch('ncurses-base'), 'ncurses-base',
	'leaves unqualified package names unchanged');

{
no warnings qw(once redefine);
local *backquote_command = sub {
	return "Inst libtinfo6:amd64 [6.3-2ubuntu0.1] ".
	       "(6.3-2ubuntu0.2 Ubuntu:22.04/jammy-updates [amd64])\n";
	};
local *clean_language = sub { };
local *reset_environment = sub { };

my @ops = update_system_operations('libtinfo6');
is($ops[0]->{'name'}, 'libtinfo6',
	'normalizes package names from simulated APT operations');
}

{
no warnings qw(once redefine);
my $apt_output = "Setting up libtinfo6:amd64 (6.3-2ubuntu0.2) ...\n";
my $yes_input = "";
my $executed_command = "";
my @reheld;
local *additional_log = sub { };
local *backquote_logged = sub { return ""; };
local *clean_language = sub { };
local *html_escape = sub { return $_[0]; };
local *reset_environment = sub { };
local *list_update_system_holds = sub {
	return ('libtinfo6:amd64', 'held-dependency:i386');
	};
local *update_system_hold = sub {
	my ($packages, $hold) = @_;
	@reheld = @$packages if ($hold);
	return undef;
	};
local *text = sub { return $_[0]; };
local *transname = sub { return "/tmp/software-apt-test-yes"; };
local *open_tempfile = sub {
	my ($fh) = @_;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, ">", \$yes_input)
		or die "open temp input: $!";
	};
local *print_tempfile = sub {
	my ($fh, @text) = @_;
	no strict 'refs';
	my $handle = ref($fh) ? $fh : \*{$fh};
	print $handle @text;
	};
local *close_tempfile = sub {
	my ($fh) = @_;
	no strict 'refs';
	close(ref($fh) ? $fh : \*{$fh});
	};
local *open_execute_command = sub {
	my ($fh, $command) = @_;
	$executed_command = $command;
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, "<", \$apt_output)
		or die "open simulated apt output: $!";
	};
local $config{'package_system'} = 'debian';
local $apt_get_command = 'aptitude';

my $printed = "";
open(my $stdout, ">", \$printed) or die "open captured stdout: $!";
local *STDOUT = $stdout;
my @installed = update_system_install(
	'libtinfo6', undef, 1, '--allow-change-held-packages');
is_deeply(\@installed, [ 'libtinfo6' ],
	'normalizes package names returned by apt install output');
like($executed_command, qr/apt-get -y --allow-change-held-packages install/,
	'uses apt-get for the held-package override even in aptitude mode');
is_deeply(\@reheld, [ 'libtinfo6:amd64', 'held-dependency:i386' ],
	'restores all exact holds after explicitly updating a held package');

$executed_command = "";
@reheld = ( );
update_system_install('libtinfo6', undef, 1);
like($executed_command, qr/^aptitude -y install/,
	'continues using configured aptitude mode for regular installs');
is_deeply(\@reheld, [ ], 'does not reapply holds after a regular install');
}

{
no warnings qw(once redefine);
local *clean_language = sub { };
local *reset_environment = sub { };
local *has_command = sub {
	return $_[0] eq 'aptitude' || $_[0] eq 'apt-mark';
	};
local *open_execute_command = sub {
	my ($fh, $command) = @_;
	my $output = $command =~ /^dpkg / ?
		"alpha hold\ndelta:amd64 hold\n" :
	      $command =~ /^aptitude / ?
		".h beta 1.0 installed\n" :
	      $command =~ /^apt-mark / ?
		"gamma\ndelta:amd64\n" : "";
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$output)
		or die "open simulated holds: $!";
	};

is_deeply([ list_update_system_holds() ],
	[ qw(alpha beta delta:amd64 gamma) ],
	'combines held packages without discarding architecture qualifiers');
}

{
no warnings qw(once redefine);
my $apt_output =
	"Listing...\n".
	"held-pkg/stable 2.0 amd64 [upgradable from: 1.0]\n".
	"regular-pkg/stable 3.0 amd64 [upgradable from: 2.0]\n";
local *clean_language = sub { };
local *reset_environment = sub { };
local *execute_command = sub { return 0; };
local *list_update_system_holds = sub { return ('held-pkg'); };
local *has_command = sub { return $_[0] eq 'apt'; };
local *open_execute_command = sub {
	my ($fh, $command) = @_;
	my $output = $command =~ /^apt list / ? $apt_output : "";
	no strict 'refs';
	open(ref($fh) ? $fh : \*{$fh}, '<', \$output)
		or die "open simulated updates: $!";
	};

my @normal = update_system_updates(0);
is_deeply([ map { $_->{'name'} } @normal ], [ 'regular-pkg' ],
	'default APT updates still exclude held packages');
my @with_holds = update_system_updates(1);
is_deeply([ map { $_->{'name'} } @with_holds ],
	[ 'held-pkg', 'regular-pkg' ],
	'held-update query includes regular and held packages');
ok($with_holds[0]->{'held'}, 'marks the held update');
ok(!$with_holds[1]->{'held'}, 'does not mark a regular update as held');
}

{
no warnings qw(once redefine);
my $command;
local *has_command = sub { return '/usr/bin/apt-mark'; };
local *unique = sub {
	my %seen;
	return grep { !$seen{$_}++ } @_;
	};
local *trim = sub {
	my ($value) = @_;
	$value =~ s/^\s+|\s+$//g;
	return $value;
	};
local *clean_language = sub { };
local *reset_environment = sub { };
local *execute_command_logged = sub {
	my ($cmd, undef, $stdout) = @_;
	$command = $cmd;
	$$stdout = "";
	return 0;
	};

is(update_system_hold([ 'webmin-virtual-server', 'webmin-virtual-server' ], 1),
	undef, 'holds packages successfully');
is($command, 'apt-mark hold webmin\-virtual\-server',
	'builds a quoted apt-mark hold command without duplicates');
}

done_testing();
