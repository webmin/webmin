#!/usr/bin/perl
# Tests for login privileges and RPC authorization in web-lib-funcs.pl.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

our ($remote_user, $base_remote_user);
my (%test_acls, %test_modules);
my $test_product = 'webmin';
my ($test_master, $test_reseller) = (1, 0);

# Supply login context without loading modules or workstation configuration.
{
	no warnings qw(redefine once);
	*main::get_module_acl = sub { return %{$test_acls{$_[0]} || { }}; };
	*main::foreign_available = sub { return $test_modules{$_[0]}; };
	*main::foreign_require = sub { };
	*main::get_product_name = sub { return $test_product; };
	*virtual_server::master_admin = sub { return $test_master; };
	*virtual_server::reseller_admin = sub { return $test_reseller; };
}

# Check the public helpers used by themes, not just the mode string.
sub check_mode
{
my ($expected) = @_;
is(main::webmin_user_login_mode(), $expected, "login mode is $expected");
is(!!main::webmin_user_is_admin(), !!($expected eq 'root'),
   'admin status matches the login role');
ok(main::webmin_user_is($expected), 'role predicate matches');
}

$remote_user = $base_remote_user = 'webminadmin';

# New and existing administrators keep their UI privileges for every RPC mode.
foreach my $rpc (0 .. 3) {
	subtest "administrator with rpc=$rpc" => sub {
		%test_acls = (webminadmin => { rpc => $rpc });
		check_mode('root');
		is(0 + main::webmin_user_can_rpc(), (0, 1, 0, 2)[$rpc],
		   'RPC authorization still follows the RPC setting');
	};
}

# Either login identity can require safe mode, regardless of RPC permission.
foreach my $safe_user ('webminadmin', 'unixlogin') {
	subtest "safe restriction on $safe_user" => sub {
		local $remote_user = 'unixlogin';
		foreach my $rpc (0 .. 3) {
			%test_acls = (webminadmin => { rpc => $rpc },
				     unixlogin => { rpc => $rpc });
			$test_acls{$safe_user}->{'_safe'} = 1;
			check_mode('safe-user');
			}
	};
}

subtest 'different login identities with RPC disabled' => sub {
	local $remote_user = 'unixlogin';
	%test_acls = (webminadmin => { rpc => 0 }, unixlogin => { rpc => 0 });
	check_mode('root');
};

# Product-specific roles must not gain admin privileges when RPC is disabled.
subtest 'product roles with RPC disabled' => sub {
	%test_acls = (webminadmin => { rpc => 0 });
	$test_product = 'usermin';
	check_mode('mail-user');
	$test_product = 'webmin';

	%test_modules = ('virtual-server' => 1);
	check_mode('root');
	$test_master = 0;
	check_mode('virtual-owner');
	$test_reseller = 1;
	check_mode('virtual-reseller');

	%test_modules = ('server-manager' => 1);
	local $server_manager::access{'owner'} = 1;
	check_mode('cloud-owner');
	$server_manager::access{'owner'} = 0;
	check_mode('root');
};

done_testing();
