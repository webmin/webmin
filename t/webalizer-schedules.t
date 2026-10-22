#!/usr/bin/perl
# Exercise Webalizer scheduling without reading or changing system crontabs.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
$INC{'./webalizer-lib.pl'} = 1;
$main::cron_cmd = '/fixture/webalizer.pl';
my (@jobs, @actions, @saved, @audit, %configs, %locks);

# Load the real ACL, schedule-copy and restore helpers without module startup.
for my $source (['webalizer-lib.pl', qw(can_edit_log lconf_to_cron)],
		['backup_config.pl', 'post_restore']) {
	my ($file, @subs) = @$source;
	open(my $fh, '<', "$root/webalizer/$file") or die $!;
	my $code = do { local $/; <$fh> };
	close($fh);
	for my $sub (@subs) {
		$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
		eval 'no strict; no warnings; '.$1;
		die $@ if $@;
		}
	}

# Keep cron reads and writes in separate copies so mutating the read cache
# alone cannot make a test pass. Existing jobs must be explicitly saved.
*cron::list_cron_jobs = sub { map { { %$_ } } @jobs };
*cron::cron_file = sub { $_[0]->{'file'} || '/fixture/crontab' };
*cron::change_cron_job = sub {
	my ($job) = @_;
	die "Cron update was not locked\n" unless $locks{cron::cron_file($job)};
	my ($stored) = grep { $_->{'index'} == $job->{'index'} } @jobs;
	die "Unknown job\n" unless $stored;
	%$stored = %$job;
	push(@actions, ['change', { %$job }]);
	};
*cron::create_cron_job = sub {
	push(@jobs, { %{$_[0]} });
	push(@actions, ['create', { %{$_[0]} }]);
	};
*cron::delete_cron_job = sub {
	@jobs = grep { $_->{'index'} != $_[0]->{'index'} } @jobs;
	push(@actions, ['delete', { %{$_[0]} }]);
	};

# Isolate configuration, locking and logging; preserve the real ACL check.
*main::ReadParse = *main::foreign_require = *main::error_setup = sub { };
*main::error = sub { die "Access denied\n" };
*main::redirect = sub { };
*main::lock_file = sub { $locks{$_[0]}++ };
*main::unlock_file = sub {
	die "Unbalanced unlock\n" unless $locks{$_[0]};
	delete($locks{$_[0]}) unless --$locks{$_[0]};
	};
*main::config_file_name = sub { '/fixture/log.conf' };
*main::get_log_config = sub { return { %{$configs{$_[0]}} } };
*main::save_log_config = sub {
	$configs{$_[0]} = { %{$_[1]} };
	push(@saved, $_[0]);
	};
*main::get_all_logs = sub { map { { file => $_ } } sort keys %configs };
*main::webmin_log = sub { push(@audit, [ @_ ]) };

# seed_case(file, scheduled, command) sets up one log and an unrelated cron job.
# An undefined command means this log has no existing cron job.
sub seed_case
{
my ($file, $scheduled, $command) = @_;
%configs = ($file => { sched => $scheduled, special => '', mins => '17',
	hours => '3', days => '*', months => '*', weekdays => '1,4' });
@jobs = ({ index => 0, file => '/fixture/crontab', command => 'echo unrelated' });
if (defined($command)) {
	# Deliberately use times different from the log config: quoting must not
	# reset a user's existing cron schedule or other job properties.
	push(@jobs, { index => 1, file => '/fixture/crontab', type => 0,
		user => 'root', active => 1, command => $command, special => '',
		mins => '42', hours => '6', days => '*', months => '2,5',
		weekdays => '*', comment => 'Keep this comment' });
	}
@actions = @saved = @audit = ();
%locks = ();
%main::access = (dir => '/');
%main::in = (d => $file, enable => 1);
}

# run_action(mode) runs the actual bulk CGI or restore hook and checks cleanup.
sub run_action
{
my ($mode) = @_;
my $error;
if ($mode eq 'restore') {
	eval { main::post_restore([]) };
	$error = $@;
	}
else {
	do "$root/webalizer/mass.cgi";
	$error = $@;
	}
is($error, '', "$mode completes");
is_deeply(\%locks, {}, 'all locks are released');
}

for my $mode ('enable', 'already enabled', 'restore') {
	subtest "$mode normalizes legacy jobs" => sub {
		for my $file ('/var/log/access.log', '/var/log/site-name.access',
			'/var/log/with spaces', q{/var/log/a;'"$()&|<>}, '/var/log/100%done') {
			my $command = $main::cron_cmd.' '.quotemeta($file);
			seed_case($file, $mode eq 'enable' ? 0 : 1, "$main::cron_cmd $file");
			my $before = { %{$jobs[1]} };
			run_action($mode);
			is_deeply($jobs[1], { %$before, command => $command },
				'only the existing command changes');
			is_deeply([map { $_->[0] } @actions], ['change'],
				'the corrected job is saved, not duplicated');
			is($jobs[0]->{'command'}, 'echo unrelated', 'unrelated jobs are untouched');
			is($configs{$file}->{'sched'}, 1, 'the log is scheduled');
			is($audit[0]->[2], 1, 'bulk enable counts the corrected log') if $mode ne 'restore';

			# Repeating the action must not rewrite an already corrected job.
			@actions = @saved = ();
			run_action($mode);
			is_deeply(\@actions, [], 'a second call does not touch cron');
			is_deeply(\@saved, [], 'a second call does not rewrite the log config');
			}
		};
	}

subtest 'new and already quoted jobs keep their behavior' => sub {
	my $file = '/var/log/site with spaces';
	my $command = $main::cron_cmd.' '.quotemeta($file);
	for my $mode ('enable', 'restore') {
		seed_case($file, $mode eq 'restore' ? 1 : 0, undef);
		run_action($mode);
		is_deeply([map { $_->[0] } @actions], ['create'], 'a missing job is created');
		is($jobs[1]->{'command'}, $command, 'new jobs use the same quoted form');
		is($jobs[1]->{'user'}, 'root', 'the new job still runs as root');
		my %schedule;
		main::lconf_to_cron($configs{$file}, \%schedule);
		is_deeply({ map { $_ => $jobs[1]->{$_} } keys %schedule }, \%schedule,
			'a new job uses the configured schedule');

		seed_case($file, $mode eq 'restore' ? 1 : 0, $command);
		my $before = { %{$jobs[1]} };
		run_action($mode);
		is_deeply(\@actions, [], 'already quoted jobs are not rewritten');
		is_deeply($jobs[1], $before, 'the existing job is unchanged');
		is($configs{$file}->{'sched'}, 1, 'bulk enable still sets the schedule flag');
		}
	};

subtest 'disable and access checks remain unchanged' => sub {
	my $file = '/var/log/log;name';
	for my $command ("$main::cron_cmd $file", $main::cron_cmd.' '.quotemeta($file)) {
		seed_case($file, 1, $command);
		$main::in{'enable'} = 0;
		run_action('disable');
		is_deeply([map { $_->[0] } @actions], ['delete'], 'disable removes either form');
		is(scalar(@jobs), 1, 'only the unrelated job remains');
		is($configs{$file}->{'sched'}, 0, 'disable clears the schedule flag');
		}
	seed_case($file, 0, "$main::cron_cmd $file");
	run_action('restore');
	is_deeply(\@actions, [], 'restore leaves unscheduled logs alone');
	for my $acl ({dir => ''}, {view => 1}, {dir => '', view => 1}) {
		seed_case($file, 1, "$main::cron_cmd $file");
		%main::access = (dir => '/', %$acl);
		do "$root/webalizer/mass.cgi";
		is($@, "Access denied\n", 'bulk enable enforces access restrictions');
		is_deeply(\@actions, [], 'denied requests do not touch cron');
		is_deeply(\@saved, [], 'denied requests do not save configuration');
		}
	};

done_testing();
