#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $root = File::Spec->rel2abs(
	File::Spec->catdir(dirname(__FILE__), '..'));
unshift(@INC, $root) if (!grep { $_ eq $root } @INC);
my $script = File::Spec->catfile($root, 'bin', 'passwd');
do $script or die "failed to load $script: $@ $!";

sub capture_stderr
{
	my ($code) = @_;
	my $output = '';
	open(my $stderr, '>', \$output) or die "open captured stderr: $!";
	{
		local *STDERR = $stderr;
		$code->();
	}
	return $output;
}

sub prompt_with
{
	my ($input) = @_;
	my $output = '';
	open(my $stdin, '<', \$input) or die "open simulated stdin: $!";
	open(my $stdout, '>', \$output) or die "open captured stdout: $!";
	my $target;
	{
		local *STDIN = $stdin;
		local *STDOUT = $stdout;
		$target = prompt_password_target('root');
	}
	return ($target, $output);
}

is(choose_password_target({}, 'web-only', 0, 0), 'webmin',
	'Webmin-only account does not need a target choice');
is(choose_password_target({ webmin => 1 }, 'root', 1, 0), 'webmin',
	'Webmin-only target can be selected explicitly');
is(choose_password_target({ unix => 1 }, 'root', 1, 1), 'unix',
	'Unix target can be selected explicitly');
is(choose_password_target({ stdout => 1 }, 'root', 1, 1), 'webmin',
	'hash-only output does not prompt for a password target');

my $explicit_webmin_warning = capture_stderr(sub {
	is(choose_password_target(
		{ webmin => 1, password => 'secret' }, 'root', 1, 1),
		'webmin',
		'explicit Webmin-only password does not prompt');
});
is($explicit_webmin_warning, '',
	'explicit Webmin-only password does not emit a Unix-user warning');

my $password_warning = capture_stderr(sub {
	is(choose_password_target({ password => 'secret' }, 'root', 1, 1),
		'webmin',
		'command-line password explicitly selects Webmin-only behavior');
});
like($password_warning, qr/--password option explicitly sets/,
	'command-line password warns about separate Webmin-only authentication');

my $warning = capture_stderr(sub {
	is(choose_password_target({}, 'root', 1, 0), 'webmin',
		'non-interactive compatibility path keeps Webmin-only behavior');
});
like($warning, qr/is also a Unix user/,
	'non-interactive compatibility path warns about the matching Unix user');
like($warning, qr/--unix or --webmin-only/,
	'non-interactive warning explains how to select a target');

my ($default_target, $default_output) = prompt_with("\n");
is($default_target, 'unix', 'interactive prompt defaults to Unix password');
like($default_output, qr/Unix authentication in Webmin.*recommended/s,
	'interactive prompt labels Unix authentication as recommended');
like($default_output, qr/separate Webmin-only password/,
	'interactive prompt explains the separate password choice');

my ($webmin_target) = prompt_with("2\n");
is($webmin_target, 'webmin',
	'interactive prompt accepts the Webmin-only password choice');

my ($retry_target, $retry_output) = prompt_with("invalid\nu\n");
is($retry_target, 'unix', 'interactive prompt accepts Unix shorthand');
like($retry_output, qr/Invalid selection/,
	'interactive prompt retries invalid selections');

foreach my $case (
	[ { unix => 1, webmin => 1 }, qr/cannot be used together/,
	  'conflicting targets are rejected' ],
	[ { unix => 1, stdout => 1 }, qr/cannot be used together/,
	  'Unix target cannot be combined with hash-only output' ],
	[ { unix => 1, password => 'secret' }, qr/system passwd command/,
	  'Unix target rejects a command-line password' ],
	[ { unix => 1 }, qr/doesn't exist/,
	  'Unix target requires a matching Unix user' ],
	) {
	my ($options, $error, $name) = @$case;
	my $ok = eval {
		choose_password_target($options, 'missing-user', 0, 0);
		1;
	};
	ok(!$ok, $name);
	like($@, $error, "$name reports the reason");
}

done_testing();
