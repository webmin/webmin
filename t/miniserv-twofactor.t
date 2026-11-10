#!/usr/bin/perl
# Check OTP wrapper failures without starting a server or loading Webmin config.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
require "$FindBin::Bin/../miniserv-lib.pl";

# Keep wrapper files and all child-process output inside the test directory.
my $work = tempdir(CLEANUP => 1);
mkdir("$work/acl") or die "mkdir: $!";
local @miniserv::roots = ($work);
local %miniserv::config = (port => 10000);
local $miniserv::config_file = "$work/miniserv.conf";
# log_error(message): capture child errors without opening a real server log.
local *miniserv::log_error = sub { print STDERR $_[0], "\n"; };
# get_user_details(user, origuser): supply an enrolled account without user files.
local *miniserv::get_user_details = sub {
	return { twofactor_provider => 'totp', twofactor_id => 'fixture',
		 twofactor_apikey => '' };
	};

# wrapper(name, source): create a helper script with the requested behavior.
sub wrapper
{
my ($name, $source) = @_;
my $path = "$work/acl/$name.pl";
open(my $fh, '>', $path) or die "open: $!";
print $fh $source;
close($fh) or die "close: $!";
return $path;
}

# Capture expected Perl errors instead of printing them in the test results.
open(my $errors, '>', "$work/errors") or die "open errors: $!";
open(my $saved_stderr, '>&', \*STDERR) or die "save stderr: $!";
open(STDERR, '>&', $errors) or die "redirect stderr: $!";

# Explicit success and rejection retain the OTP wrapper's existing contract.
$miniserv::config{'twofactor_wrapper'} = wrapper('accept', 'exit(0);');
is(miniserv::validate_twofactor('fixture', '11111', 'fixture'), undef,
   'explicit verification success is accepted');
like(miniserv::validate_twofactor('fixture', '', 'fixture'), qr/No two-factor/,
     'an empty token is rejected before invoking the helper');
$miniserv::config{'twofactor_wrapper'} = wrapper('reject',
	'print "Incorrect OTP code\n"; exit(1);');
like(miniserv::validate_twofactor('fixture', '11111', 'fixture'),
     qr/Incorrect OTP code/, 'explicit rejection preserves its error message');

# Loading failures and uncaught exceptions must never authorize a login.
my @failures = (
	[ 'runtime error', wrapper('crash', 'die "OTP fixture failure\n";') ],
	[ 'syntax error', wrapper('syntax', 'my $broken = ;') ],
	[ 'empty helper', wrapper('empty', '') ],
	[ 'missing helper', "$work/acl/missing.pl" ],
	[ 'helper is a directory', "$work/acl" ],
	[ 'missing dependency', wrapper('dependency',
		'require "missing-otp-fixture-module.pm";') ],
	);
foreach my $case (@failures) {
	$miniserv::config{'twofactor_wrapper'} = $case->[1];
	ok(miniserv::validate_twofactor('fixture', '11111', 'fixture'),
	   "$case->[0] rejects OTP verification");
	}

# A return value must not stand in for an explicit verification result.
foreach my $source ('1;', '0;', 'undef;', '$! = 2; 0;', '$! = 2; undef;',
		    'open(my $fh, "<", "missing-otp-fixture"); undef;') {
	my $path = wrapper('returned', $source);
	my $pid = miniserv::execute_webmin_command($path, [ ]);
	is(waitpid($pid, 0), $pid, 'wrapper was reaped');
	is($? >> 8, 1, "returning without an exit status fails: $source");
	}

# Usermin-style wrappers replace the child with another program via exec.
my $exec_wrapper = wrapper('exec',
	'exec($^X, "-e", "exit(shift)", @ARGV) || die "exec: $!";');
foreach my $status (0, 1) {
	my $pid = miniserv::execute_webmin_command($exec_wrapper, [ $status ]);
	is(waitpid($pid, 0), $pid, 'exec wrapper was reaped');
	is($? >> 8, $status, 'exec preserves the replacement program exit status');
	}

# Run the actual cron wrapper with harmless callbacks and no installed config.
mkdir("$work/webmincron") or die "mkdir cron: $!";
open(my $cron_source, '<', "$FindBin::Bin/../webmincron/webmincron.pl") ||
	die "open cron wrapper: $!";
open(my $cron_copy, '>', "$work/webmincron/webmincron.pl") ||
	die "copy cron wrapper: $!";
print $cron_copy do { local $/; <$cron_source> };
close($cron_source);
close($cron_copy);

# Supply only the library callbacks needed by the real cron wrapper.
open(my $cron_lib, '>', "$work/webmincron/webmincron-lib.pl") ||
	die "write cron callbacks: $!";
print $cron_lib <<'EOF';
$gconfig{'logsched'} = $ARGV[0]->{'fixture_logging'};
# foreign_require(module, [file]): skip loading modules in this isolated test.
sub foreign_require { }
# foreign_call(module, function, [args...]): finish after an optional-file error.
sub foreign_call
{
print "ran\n";
open(my $fh, '<', 'missing-optional-fixture');
return undef;
}
# webmin_log(action, type, id, details): show that scheduled logging ran.
sub webmin_log { print "logged\n"; }
1;
EOF
close($cron_lib);

# Cron completion must work with logging unset, disabled, or enabled.
foreach my $logging (undef, 0, 1) {
	open(my $output, '>', "$work/cron-output") or die "cron output: $!";
	my $cron = { module => 'fixture', func => 'run', id => 'fixture',
		     fixture_logging => $logging };
	my $pid = miniserv::execute_webmin_command(
		"$work/webmincron/webmincron.pl", [ $cron ], fileno($output));
	waitpid($pid, 0);
	is($?, 0, 'cron wrapper exits successfully after an optional-file error');
	close($output);
	open(my $read_output, '<', "$work/cron-output") or die "cron output: $!";
	my $text = do { local $/; <$read_output> };
	close($read_output);
	is($text, $logging ? "ran\nlogged\n" : "ran\n",
	   'cron callback and optional logging both ran as configured');
	}

# Explicit nonzero statuses also remain available to other wrapper callers.
my $pid = miniserv::execute_webmin_command(
	wrapper('status', 'exit(7);'), [ ]);
waitpid($pid, 0);
is($? >> 8, 7, 'explicit wrapper exit status is preserved');

# Restore the test harness's error output before reporting the final result.
open(STDERR, '>&', $saved_stderr) or die "restore stderr: $!";
close($errors);
done_testing();
