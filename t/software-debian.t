#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";

do './software/debian-lib.pl' or die $@ || $!;

sub run_busy_test
{
my ($commands, $available) = @_;
my @ran;
no warnings qw(once redefine);
local *has_command = sub {
	my ($name) = @_;
	return $available->{$name};
	};
local *backquote_command = sub {
	my ($command) = @_;
	push(@ran, $command);
	my $normalized = $command;
	$normalized =~ s/\\(.)/$1/g;
	foreach my $match (@$commands) {
		if ($normalized =~ $match->{'match'}) {
			$? = $match->{'status'} << 8;
			return $match->{'output'} || '';
			}
		}
	die "Unexpected command: $command";
	};
my $busy = package_system_busy_internal();
return ($busy, \@ran);
}

my %commands = (
	'fuser' => '/usr/bin/fuser',
	'dpkg' => '/usr/bin/dpkg',
);

my ($busy, $ran) = run_busy_test(
	[ { 'match' => qr{/var/lib/dpkg/lock-frontend},
	    'status' => 0 } ],
	\%commands);
is($busy, 1, 'reports a held dpkg frontend lock as busy');
is(scalar(@$ran), 1, 'stops checking after finding a held lock');

($busy, $ran) = run_busy_test(
	[ { 'match' => qr{/var/lib/dpkg/lock-frontend},
	    'status' => 1 },
	  { 'match' => qr{/var/lib/dpkg/lock(?:\s|$)},
	    'status' => 1 },
	  { 'match' => qr{dpkg\s+--audit},
	    'status' => 0 } ],
	\%commands);
is($busy, 0, 'reports unlocked and consistent dpkg state as stable');

($busy, $ran) = run_busy_test(
	[ { 'match' => qr{/var/lib/dpkg/lock-frontend},
	    'status' => 1 },
	  { 'match' => qr{/var/lib/dpkg/lock(?:\s|$)},
	    'status' => 1 },
	  { 'match' => qr{dpkg\s+--audit},
	    'status' => 0,
	    'output' => "The following packages are only half configured.\n" } ],
	\%commands);
is($busy, 1, 'reports incomplete packages as busy');

($busy, $ran) = run_busy_test(
	[ { 'match' => qr{/var/lib/dpkg/lock-frontend},
	    'status' => 1 },
	  { 'match' => qr{/var/lib/dpkg/lock(?:\s|$)},
	    'status' => 1 },
	  { 'match' => qr{dpkg\s+--audit},
	    'status' => 2 } ],
	\%commands);
is($busy, 1, 'treats a failed dpkg audit as unsafe');

($busy, $ran) = run_busy_test(
	[ { 'match' => qr{dpkg\s+--audit},
	    'status' => 0 } ],
	{ 'dpkg' => '/usr/bin/dpkg' });
is($busy, undef, 'returns undef when lock ownership cannot be checked');

done_testing();
