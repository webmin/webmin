#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(once redefine);
use FindBin;
use Test::More;

open(my $lib, '<', "$FindBin::Bin/../cluster-passwd/cluster-passwd-lib.pl")
	or die $!;
my $code = do { local $/; <$lib> };
$code =~ /(^sub modify_on_hosts\n\{.*?^\})/ms or die 'missing modify_on_hosts';
eval "no strict; $1";
die $@ if $@;

local *cluster_useradmin::list_servers = sub { return { id => 1, host => 'fixture' }; };
local *main::remote_error_setup = sub {};
local *main::remote_foreign_require = sub {};
local *useradmin::passfiles_type = sub { return 2; };
local *main::can_edit_passwd = sub { return 1; };
local *main::text = sub { return $_[0]; };
foreach my $fail (0, 1) {
	my (@calls, @outcomes, $saved);
	my $host = { id => 1, users => [ { user => 'fixture' } ] };
	local *main::remote_foreign_call = sub {
		my (undef, undef, $func, @args) = @_;
		push(@calls, $func);
		return { user => 'fixture' } if ($func eq 'list_users');
		return 'fixture hash' if ($func eq 'encrypt_password');
		if ($func eq 'set_user_envs') {
			is($args[0]->{'user'}, 'fixture', 'passes the selected user');
			is($args[1], 'MODIFY_USER', 'sets the hook action');
			ok($args[2] eq $args[0]->{'plainpass'}, 'passes the new password');
			}
		return 'hook failed' if ($fail && $func eq 'making_changes');
		return undef;
		};
	local *cluster_useradmin::save_useradmin_host = sub { $saved = 1; };
	modify_on_hosts([$host], 'fixture', 'fixture value', 1,
			sub { push(@outcomes, $_[0]); });
	my @expected = qw(list_users encrypt_password set_user_envs making_changes);
	push(@expected, qw(modify_user made_changes other_modules)) unless $fail;
	is_deeply(\@calls, \@expected, 'hooks and update run in order');
	is(!!$saved, !$fail, 'cache updated only after a successful change');
	ok(!exists($host->{'users'}->[0]->{'plainpass'}), 'no plaintext in cache');
	is($outcomes[-1], $fail ? 1 : -4, 'reports the correct result');
	}
done_testing();
