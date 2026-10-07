#!/usr/bin/perl
# Check signal preservation across the real miniserv restart and startup code.
use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use POSIX qw(SIG_BLOCK SIGHUP SIGUSR1 SIGUSR2);

my $root = File::Spec->rel2abs(dirname(__FILE__).'/..');
my $script = File::Spec->rel2abs(__FILE__);
shift(@ARGV) if (($ARGV[0] || '') eq '--nofork');
my $mode = $ARGV[0] || '';

# Inspect the new interpreter before startup can install signal handlers.
if ($mode eq '--after-exec') {
	alarm(15);
	my $mask = POSIX::SigSet->new();
	POSIX::sigprocmask(SIG_BLOCK, undef, $mask) or die "Read signal mask: $!";
	my $blocked = $mask->ismember(SIGHUP) && $mask->ismember(SIGUSR1);
	print "Restart signals blocked across exec: ", $blocked ? 'yes' : 'no', "\n";
	exit(1) if (!$blocked);

	# Queue requests in this test process, then run the real early startup.
	kill('HUP', $$) == 1 or die "Queue restart: $!";
	kill('USR1', $$) == 1 or die "Queue reload: $!";
	@ARGV = ();
	unshift(@INC, $root);
	do "$root/miniserv.pl";
	die "Expected argument validation, got: $@ $!" if ($@ !~ /^Usage: miniserv\.pl/);
	{
		no warnings 'once';
		print "Queued restart handled: ", $miniserv::need_restart ? 'yes' : 'no', "\n";
		print "Queued reload handled: ", $miniserv::need_reload ? 'yes' : 'no', "\n";
	}

	# Startup must release its own signals without changing unrelated masks.
	POSIX::sigprocmask(SIG_BLOCK, undef, $mask) or die "Read startup mask: $!";
	print "Restart signals unblocked: ",
		!$mask->ismember(SIGHUP) && !$mask->ismember(SIGUSR1) ? 'yes' : 'no', "\n";
	print "Unrelated mask preserved: ", $mask->ismember(SIGUSR2) ? 'yes' : 'no', "\n";
	exit(0);
	}

# Exercise restart_miniserv in a child that owns no daemon sockets or files.
if ($mode eq '--restart') {
	alarm(15);
	require "$root/miniserv-lib.pl";
	{
		no warnings qw(once redefine);
		*miniserv::log_error = sub { };
		$miniserv::perl_path = $^X;
		$miniserv::miniserv_path = $script;
		@miniserv::miniserv_argv = ('--nofork', '--after-exec');
	}
	# Seed an unrelated mask to check that restart does not replace it.
	POSIX::sigprocmask(SIG_BLOCK, POSIX::SigSet->new(SIGUSR2)) or
		die "Block unrelated signal: $!";
	miniserv::restart_miniserv();
	die "restart_miniserv unexpectedly returned";
	}

open(my $child, '-|', $^X, $script, '--restart') or die "Start child: $!";
my $output = do { local $/; <$child> };
close($child);
is($?, 0, 'restart and startup finish without a fatal signal') or diag($output);
foreach my $check ('Restart signals blocked across exec', 'Queued restart handled',
		  'Queued reload handled', 'Restart signals unblocked',
		  'Unrelated mask preserved') {
	like($output, qr/^\Q$check\E: yes$/m, $check);
	}
done_testing();
