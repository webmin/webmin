#!/usr/bin/perl
# Exercise stream permissions with a fake journalctl, never the host journal.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
open(my $lib, '<', "$root/logviewer/logviewer-lib.pl") or die $!;
my $source = do { local $/; <$lib> };
close($lib);
my ($check) = $source =~ /^(sub can_edit_log\n\{.*?^\})/ms;
die 'Missing can_edit_log' if (!$check);
eval "no strict; $check";
die $@ if ($@);

# Keep module startup and command discovery independent of the host.
$INC{'./logviewer-lib.pl'} = 1;
*main::ReadParse = *main::foreign_require = sub { };
my $command;
*main::get_systemctl_cmds = sub {
	return { id => 'journal-1', cmd => $command };
	};

# The only executable in the child's PATH records invocation and emits a line.
my $tmp = tempdir(CLEANUP => 1);
my $marker = "$tmp/started";
open(my $fake, '>', "$tmp/journalctl") or die $!;
print $fake "#!$^X\n", <<'PROGRAM';
use strict;
use warnings;
open(my $fh, '>', $ENV{'LOGVIEWER_TEST_MARKER'}) or die $!;
print $fh join(' ', @ARGV);
close($fh) or die $!;
print "fixture journal line\n";
PROGRAM
close($fake) or die $!;
chmod(0700, "$tmp/journalctl") or die $!;

foreach my $case (
	[ 'syslog denied', 0, '', 'journal-1', 'journalctl --lines 10', 0 ],
	[ 'syslog unset', undef, '', 'journal-1', 'journalctl --lines 10', 0 ],
	[ 'syslog allowed', 1, '', 'journal-1', 'journalctl --lines 10', 1 ],
	[ 'log excluded', 1, '/fixture/other', 'journal-1',
		'journalctl --lines 10', 0 ],
	[ 'unknown log', 1, '', 'journal-missing', 'journalctl --lines 10', 0 ],
	[ 'non-journal command', 1, '', 'journal-1', 'other-command', 0 ]) {
	my ($label, $syslog, $logs, $id, $cmd, $allowed) = @$case;
	$command = $cmd;
	unlink($marker) if (-e $marker);
	# Run the real CGI in a child so its exit cannot terminate the test suite.
	my $pid = open(my $output, '-|');
	die "fork: $!" if (!defined($pid));
	if (!$pid) {
		$ENV{'PATH'} = $tmp;
		$ENV{'LOGVIEWER_TEST_MARKER'} = $marker;
		%main::access = (syslog => $syslog, logs => $logs);
		%main::in = (idx => $id);
		%main::text = (save_ecannot3 => 'Access denied');
		do "$root/logviewer/view_log_progress.cgi";
		die $@ if ($@);
		exit 0;
		}
	my $body = do { local $/; <$output> };
	close($output);
	is($? >> 8, 0, "$label: CGI completes");
	is($body, "Content-Type: text/plain\n\n".
		($allowed ? "fixture journal line\n" : 'Access denied'),
		"$label: correct response");
	is(-e $marker ? 1 : 0, $allowed,
		"$label: command runs only when permitted");
	if ($allowed) {
		# Authorized streams retain follow mode and omit the old line limit.
		open(my $args, '<', $marker) or die $!;
		is(do { local $/; <$args> }, '--follow', 'stream arguments preserved');
		close($args);
		}
	}

done_testing();
