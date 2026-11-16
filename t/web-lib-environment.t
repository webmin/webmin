#!/usr/bin/perl
# Tests nested environment cleanup and exact restoration.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);

my $root = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..'));
require File::Spec->catfile($root, 'web-lib-funcs.pl');

my %original = (
	'PATH' => '/bin:/usr/bin',
	'LANG' => 'de_DE.UTF-8',
	'LANGUAGE' => 'de',
	'LC_ALL' => 'de_DE.UTF-8',
	'LC_MESSAGES' => 'de_DE.UTF-8',
	'LOCALE' => 'de_DE.UTF-8',
	'WEBMIN_CONFIG' => '/etc/webmin',
	'HTTP_ACCEPT' => 'text/html',
	'HTTP_COOKIE' => 'fixture-only',
	);

{
local %ENV = %original;
no warnings 'once';
local @main::clean_environment_stack;
local %main::UNCLEAN_ENV;

main::clean_environment();
$ENV{'WEBMIN_CONFIG'} = '/nested/etc/webmin';
main::clean_environment();
main::clean_language();
main::reset_environment();

ok(!exists($ENV{'WEBMIN_CONFIG'}),
	'language reset preserves the inner environment cleanup');
is($ENV{'LANG'}, $original{'LANG'}, 'language reset restores the locale');

main::reset_environment();
is($ENV{'WEBMIN_CONFIG'}, '/nested/etc/webmin',
	'nested reset restores the outer cleaned environment');
ok(!exists($ENV{'HTTP_ACCEPT'}),
	'nested reset does not restore the original request environment');

main::reset_environment();
is_deeply({ %ENV }, \%original,
	'outer reset restores the original environment exactly');
}

# Mixed cleanup calls must unwind in order without consuming an outer snapshot.
for my $order (
	[ 'clean_language' ],
	[ 'clean_language', 'clean_language' ],
	[ 'clean_environment', 'clean_language' ],
	[ 'clean_language', 'clean_environment' ],
	[ 'clean_environment', 'clean_language', 'clean_language' ]) {
	local %ENV = %original;
	no warnings qw(once redefine);
	local @main::clean_environment_stack;
	local %main::UNCLEAN_ENV;
	my @saved;
	for my $call (@$order) {
		push(@saved, { %ENV });
		my $cleanup = main->can($call);
		$cleanup->();
		if ($call eq 'clean_language') {
			# Language cleanup changes locale variables only.
			is_deeply([ @ENV{qw(LANG LANGUAGE LC_ALL LC_MESSAGES LOCALE)} ],
				[ ('') x 5 ], 'language overrides are cleared');
			is($ENV{'WEBMIN_CONFIG'}, $saved[-1]->{'WEBMIN_CONFIG'},
				'language cleanup preserves non-locale variables');
			}
		# Distinct state at each level exposes restoring the wrong snapshot.
		$ENV{'LANG'} = 'fr_FR.UTF-8';
		$ENV{'WEBMIN_ENV_TEST'} = scalar(@saved);
		}
	for my $expected (reverse @saved) {
		main::reset_environment();
		is_deeply({ %ENV }, $expected, join(' / ', @$order).' unwinds one level');
		}
	main::reset_environment();
	is_deeply({ %ENV }, \%original, 'extra reset leaves the environment alone');
	ok(!%main::UNCLEAN_ENV, 'final reset clears the legacy snapshot');
	}

# RPM selection must not restore request variables before the install command.
{
require File::Spec->catfile($root, 'software', 'rpm-lib.pl');
my $tmp = tempdir(TMPDIR => 1, CLEANUP => 1);
open(my $rpm, '>', "$tmp/fixture.rpm") or die $!;
close($rpm) or die $!;
no warnings qw(once redefine);
local *main::translate_filename = sub { $_[0] };
local *main::transname = sub { "$tmp/command-output" };
local *main::unlink_file = sub { 1 };
local *main::backquote_command = sub {
	return $_[0] =~ /^rpm / ? "fixture\n" : '';
	};
for my $outer_cleanup (0, 1) {
	for my $source ($tmp, "$tmp/*.rpm") {
		local %ENV = %original;
		local @main::clean_environment_stack;
		local %main::UNCLEAN_ENV;
		main::clean_environment() if ($outer_cleanup);
		my %outer = %ENV;
		my %install_env;
		# Capture the install environment without running RPM on the host.
		local *main::system_logged = sub {
			%install_env = %ENV;
			return 0;
			};
		is(main::install_package($source, 'fixture', { }), undef,
			'RPM selection and simulated install succeed');
		my %expected = %outer;
		@expected{qw(LANG LANGUAGE LC_ALL LC_MESSAGES LOCALE)} = ('') x 5;
		is_deeply(\%install_env, \%expected,
			'RPM install keeps caller cleanup and uses English output');
		is_deeply({ %ENV }, \%outer, 'RPM returns the caller environment');
		main::reset_environment() if ($outer_cleanup);
		is_deeply({ %ENV }, \%original, 'outer RPM cleanup restores exactly');
		}
	}
}

done_testing();
