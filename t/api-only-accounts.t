#!/usr/bin/perl
# Verify API-only credentials never acquire generic RPC through legacy flags.

use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";

my %policy;
$main::base_remote_user = 'integration';
# get_module_acl(user, module): supply only this test's global policy.
*main::get_module_acl = sub {
	is($_[0], 'integration', 'policy belongs to authenticated base user');
	is($_[1], '', 'policy is global, not a module permission');
	return %policy;
	};

is(main::webmin_user_api_only(), undef, 'ordinary users have no endpoint restriction');
# Endpoint restrictions override both unrestricted and RPC-only legacy modes.
for my $mode (0, 1, 3) {
	%policy = (rpc => $mode, api_only => 'virtual-server/remote.cgi');
	is(main::webmin_user_api_only(), 'virtual-server/remote.cgi',
		'API endpoint returned independently of legacy RPC flag');
	is(main::webmin_user_can_rpc(), 0, "API-only account denies RPC mode $mode");
	}
# Without an endpoint restriction, existing RPC mode behavior is unchanged.
%policy = (rpc => 1);
is(main::webmin_user_can_rpc(), 1, 'ordinary explicit RPC permission unchanged');
%policy = (rpc => 3);
is(main::webmin_user_can_rpc(), 2, 'legacy RPC-only account behavior unchanged');
%policy = (rpc => 0);
is(main::webmin_user_can_rpc(), 0, 'ordinary RPC denial unchanged');
done_testing();
