#!/usr/bin/perl
# Functional tests for the xterm module.
#
# Loads xterm-lib.pl (and acl_security.pl) as libraries. shellserver.pl
# remains an executable entry point covered by compile tests; its pure
# helpers live in xterm-lib.pl so we can test them in isolation.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Temp qw(tempdir);
# MIME::Base64 is loaded lazily inside the verify_websocket_key subtest;
# loading it before WebminCore triggers a prototype-mismatch warning when
# WebminCore re-declares encode_base64/decode_base64 with no prototype.

sub script_dir
{
    my $path = $0;
    if ($path =~ m{^/}) {
        $path =~ s{/[^/]+$}{};
        return $path;
    }
    my $cwd = `pwd`;
    chomp($cwd);
    if ($path =~ m{/}) {
        $path =~ s{/[^/]+$}{};
        return $cwd.'/'.$path;
    }
    return $cwd;
}

my $bindir = script_dir();
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir  = tempdir(CLEANUP => 1);
open(my $cfh, ">", "$confdir/config") or die "config: $!";
print $cfh "os_type=linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);
$ENV{'WEBMIN_CONFIG'}        = $confdir;
$ENV{'WEBMIN_VAR'}           = $vardir;
$ENV{'FOREIGN_MODULE_NAME'}  = 'xterm';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";

# acl_security.pl requires xterm-lib.pl by path string. Load it once
# ourselves, then pre-populate %INC so the later require is a no-op and
# the test does not get duplicate-subroutine warnings. Test cwd is the
# module dir, so '.' is on the search path for do() to find it.
push @INC, '.';
{
	my $file = "$bindir/../xterm-lib.pl";
	do $file or die "load xterm-lib.pl: $@ $!";
	$INC{$_} = $file for ('xterm-lib.pl', './xterm-lib.pl', $file);
}

require "./acl_security.pl";

our (%in, %access);

# config_pre_load —
# `size` only makes sense in old themes that don't drive a JS-side resize.
# Authentic (XMLHttpRequest) ships its own resize, so the option must be
# stripped from the config-editor listing in that branch and left alone
# otherwise. We exercise both paths plus the degenerate-arg cases that
# the production callsite can hand us.
subtest 'config_pre_load' => sub {
	# XHR branch: size is removed from both the info hash and the order array.
	{
		local $ENV{'HTTP_X_REQUESTED_WITH'} = 'XMLHttpRequest';
		my %info = (size => {}, fontsize => {}, locale => {});
		my @order = qw(size fontsize locale);
		config_pre_load(\%info, \@order);
		ok(!exists $info{'size'},     'XHR: size removed from info hash');
		ok( exists $info{'fontsize'}, 'XHR: unrelated keys preserved');
		is_deeply(\@order, [qw(fontsize locale)],
		          'XHR: size removed from order array');
	}

	# Non-XHR branch: nothing is touched.
	{
		local $ENV{'HTTP_X_REQUESTED_WITH'} = '';
		my %info = (size => {}, fontsize => {});
		my @order = qw(size fontsize);
		config_pre_load(\%info, \@order);
		ok(exists $info{'size'},      'non-XHR: size preserved');
		is_deeply(\@order, [qw(size fontsize)],
		          'non-XHR: order array preserved');
	}

	# Header unset behaves like non-XHR (no uninit warning).
	{
		local %ENV = %ENV;
		delete $ENV{'HTTP_X_REQUESTED_WITH'};
		my %info = (size => {});
		my @warnings;
		local $SIG{__WARN__} = sub { push @warnings, $_[0]; };
		config_pre_load(\%info, undef);
		ok(exists $info{'size'},      'unset header: size preserved');
		is(scalar @warnings, 0,       'unset header: no uninit warning');
	}

	# Order arg is optional / may be a non-arrayref — must not crash.
	{
		local $ENV{'HTTP_X_REQUESTED_WITH'} = 'XMLHttpRequest';
		my %info = (size => {});
		eval { config_pre_load(\%info, undef); };
		is($@, '', 'XHR with undef order arg does not die');
		ok(!exists $info{'size'}, 'XHR with undef order arg still strips size');
	}
};

# verify_websocket_key — handshake auth
#
# miniserv.pl rewrites the inbound Sec-WebSocket-Key to base64(session_id)
# before forwarding to the shellserver. Equality of the rewritten key with
# our base64-encoded local copy of session_id proves the connection came
# through the Webmin proxy and is bound to this user's session. Anything
# else (missing, empty, mismatched, only whitespace) must reject.
subtest 'verify_websocket_key' => sub {
	# require (not use) MIME::Base64 to avoid importing its prototyped
	# encode_base64 into main:: where it would clash with WebminCore's.
	require MIME::Base64;
	my $sid = 'abcdef0123456789' x 2;
	my $b64 = MIME::Base64::encode_base64($sid);

	is(verify_websocket_key($b64,         $sid), 1,
	   'base64(session_id) matches');
	(my $stripped = $b64) =~ s/\s//g;
	is(verify_websocket_key($stripped,    $sid), 1,
	   'whitespace-stripped key still matches (encode_base64 wraps lines)');

	is(verify_websocket_key('wrong-key',  $sid), 0,
	   'arbitrary key rejected');
	is(verify_websocket_key($b64,         'different-session'), 0,
	   'right key but wrong session rejected');
	is(verify_websocket_key(undef,        $sid), 0, 'undef key rejected');
	is(verify_websocket_key($b64,         undef), 0, 'undef session rejected');
	is(verify_websocket_key('',           $sid), 0, 'empty key rejected');
	is(verify_websocket_key($b64,         ''),    0, 'empty session rejected');
	is(verify_websocket_key("   \t\n",    $sid),  0,
	   'whitespace-only key rejected (would otherwise compare empty == empty)');

	# Reflected attack: if a client could replay miniserv's rewritten key
	# back as some OTHER session's id, we'd be in trouble. Pin: the function
	# compares against the FULL base64 of the local session, not a substring.
	my $other_sid = 'zzzz1111';
	is(verify_websocket_key($b64, $other_sid), 0,
	   'key for one session never matches a different session');
};

# parse_resize_message — xterm.js resize signal
#
# The browser sends a custom out-of-band string on terminal resize:
#   literal backslash + "033[8;(rows);(cols)t"
# Anything else is normal keyboard input and must be forwarded to the shell
# unchanged. Important security contract: a real ANSI CSI 8;... escape
# (chr(27)) must NOT be interpreted as resize — otherwise a remote that
# can write to the user's terminal output could be confused with input,
# though here input flows the other way it's still hygiene worth pinning.
subtest 'parse_resize_message' => sub {
	is_deeply([parse_resize_message('\\033[8;(24);(80)t')],
	          [24, 80],
	          'valid resize message parses to (rows, cols)');
	is_deeply([parse_resize_message('\\033[8;(1);(1)t')],
	          [1, 1], 'small terminal');
	is_deeply([parse_resize_message('\\033[8;(9999);(9999)t')],
	          [9999, 9999], 'large terminal');

	# Anything else is not a resize.
	is_deeply([parse_resize_message('hello')],          [], 'plain text is not resize');
	is_deeply([parse_resize_message('')],               [], 'empty string is not resize');
	is_deeply([parse_resize_message(undef)],            [], 'undef is not resize');
	is_deeply([parse_resize_message("\033[8;24;80t")],  [],
	          'real ANSI ESC sequence (chr 27) is not the custom format');
	is_deeply([parse_resize_message('\\033[8;24;80t')], [],
	          'missing parens (real CSI shape) not accepted');
	is_deeply([parse_resize_message('prefix\\033[8;(24);(80)t')], [],
	          'must match from start of message');
	is_deeply([parse_resize_message('\\033[8;(24);(80)textra')],  [],
	          'must match to end of message');
	is_deeply([parse_resize_message('\\033[8;(-1);(80)t')], [],
	          'negative dimensions rejected');
	is_deeply([parse_resize_message('\\033[8;(abc);(80)t')], [],
	          'non-numeric dimensions rejected');

	# Return values are real numbers (not strings) so downstream ioctl()
	# pack("s2", ...) sees a sane integer.
	my ($r, $c) = parse_resize_message('\\033[8;(40);(120)t');
	cmp_ok($r, '==', 40,  'rows is numeric');
	cmp_ok($c, '==', 120, 'cols is numeric');
};

# resolve_shell_user — which Unix account does the terminal run as?
#
# The contract (see acl_security.pl for the UI / docs/access.html for the
# operator-facing model):
#
#   - access user '*'   → always the authenticated user. No override.
#   - access user 'root', sudoenforce on, remote_user is a real local
#                          account → prefer the authenticated user over root.
#   - access user 'root', remote_user same as access user (e.g. logged in as
#                          root) → keep root.
#   - config user override → applies only when the resolved user is still
#                          'root'.
#   - in{user} → only honored when the resolved user is still 'root' AFTER
#                the config override (i.e. the admin actually allowed root).
#
# This is the core privilege-boundary logic. Each scenario is a security
# contract.
subtest 'resolve_shell_user' => sub {
	# access user '*': start from authenticated user. For non-root
	# remote_user this is effectively "no override possible" — the
	# trailing branches only act when $user eq 'root', so an alice-as-
	# alice resolution can't be redirected.
	is(resolve_shell_user({user => '*'}, 'alice', {}, {}),
	   'alice', "'*' with non-root authuser stays as authuser");
	is(resolve_shell_user({user => '*'}, 'alice', {user => 'bob'}, {}),
	   'alice', "'*' with non-root authuser ignores in{user}");
	is(resolve_shell_user({user => '*'}, 'alice', {}, {user => 'configured'}),
	   'alice', "'*' with non-root authuser ignores config{user}");

	# Edge case carried forward from the inline version: when access='*'
	# AND the authenticated user IS root, $user lands at "root" and the
	# trailing config{user} / in{user} branches still apply. Functionally
	# benign (root can do anything anyway) but pinned so a future refactor
	# doesn't accidentally change it without intent.
	is(resolve_shell_user({user => '*'}, 'root', {user => 'shell-svc'}, {}),
	   'shell-svc',
	   "'*' with root authuser: in{user} still routes (pre-existing behavior)");

	# access user 'root', logged in as root → stay root.
	is(resolve_shell_user({user => 'root', sudoenforce => 1},
	                      'root', {}, {}),
	   'root',
	   "'root' + remote_user=root stays root");

	# config{user} override applies when the resolved user is still root.
	is(resolve_shell_user({user => 'root', sudoenforce => 1},
	                      'root', {}, {user => 'shell-svc'}),
	   'shell-svc',
	   'config{user} overrides remaining-root');

	# in{user} override is honored only when the resolved user is still
	# 'root' — i.e. the admin explicitly allowed root.
	is(resolve_shell_user({user => 'root', sudoenforce => '0'},
	                      'root', {user => 'bob'}, {}),
	   'bob',
	   'in{user} override honored when user remained root');

	# Empty in{user} doesn't trigger the override branch.
	is(resolve_shell_user({user => 'root', sudoenforce => '0'},
	                      'root', {user => ''}, {}),
	   'root', 'empty in{user} not treated as override');

	# Empty / missing access{user} returns undef rather than producing a
	# nonsense result the caller might try to exec.
	is(resolve_shell_user({user => ''}, 'alice', {}, {}),
	   undef, 'empty access{user} returns undef');
	is(resolve_shell_user({}, 'alice', {}, {}),
	   undef, 'missing access{user} returns undef');

	# Specific named user in access{user} (neither '*' nor 'root') flows
	# through unchanged.
	is(resolve_shell_user({user => 'jenkins'},
	                      'alice', {user => 'attacker'}, {}),
	   'jenkins',
	   'specific named access user is honored as-is and cannot be overridden');

	# Sudoenforce path needs a real non-root local user with a home dir.
	# Use the test process's own account when it's not running as root.
	# This is the key privilege boundary: the admin allows 'root' in the
	# ACL, sudoenforce is on, the Webmin-authenticated user exists locally
	# → the shell drops to that user. Once de-rooted, the URL-borne
	# in{user} parameter MUST NOT be honored as a re-escalation channel.
	my @me = getpwuid($<);
	SKIP: {
		skip 'sudoenforce path needs a non-root local user', 4
			if !@me || $me[0] eq 'root' || !$me[7];
		my $local = $me[0];

		# sudoenforce on + remote_user is a real local non-root account
		# → drop to that user.
		is(resolve_shell_user({user => 'root', sudoenforce => 1},
		                      $local, {}, {}),
		   $local,
		   'sudoenforce on prefers authenticated non-root user when local');

		# sudoenforce off keeps root even when remote_user is a local
		# non-root account.
		is(resolve_shell_user({user => 'root', sudoenforce => '0'},
		                      $local, {}, {}),
		   'root',
		   'sudoenforce=0 keeps root regardless of authenticated user');

		# config{user} does NOT override once the sudo path has already
		# resolved away from root (the if-eq-root gate is closed).
		is(resolve_shell_user({user => 'root', sudoenforce => 1},
		                      $local, {}, {user => 'shell-svc'}),
		   $local,
		   'config{user} skipped when sudo path already de-rooted');

		# Pinning current behavior: when access{user}='root' AND the
		# user has supplied in{user}, the elsif's `!$in{'user'}` gate
		# CLOSES the sudo-preference branch, leaving $user='root', and
		# the trailing override then sets $user=in{user}. Effect:
		# sudoenforce is a default ("prefer non-root if user didn't
		# choose"), not a hard guard. An explicit ?user=X bypasses it
		# even when the authenticated user has a local account.
		#
		# Worth flagging: the admin model treats access{user}='root' as
		# "this Webmin user may run shells as any local user", and the
		# trailing override honors that. But operators relying on
		# sudoenforce as a hard "never run as root unless impossible"
		# guard would be surprised. See bugs-found note.
		is(resolve_shell_user({user => 'root', sudoenforce => 1},
		                      $local, {user => 'daemon'}, {}),
		   'daemon',
		   'in{user} override bypasses sudoenforce (sudoenforce is a default, not a hard guard)');
	}
};

# acl_security_save — parsing of the ACL editor form
#
# The mapping from form fields back into the stored ACL hash. user_def=1
# means "same as authenticated user" (stored as '*'); otherwise the typed
# username is stored verbatim. sudoenforce is 1/0 normalised.
subtest 'acl_security_save' => sub {
	# user_def=1 → '*'
	{
		local %in = (user_def => 1, user => 'ignored', sudoenforce => 1);
		my %o;
		acl_security_save(\%o);
		is($o{'user'},        '*', 'user_def=1 stores *');
		is($o{'sudoenforce'},  1,  'sudoenforce=1 stored as 1');
	}

	# user_def=0 → in{user} stored verbatim
	{
		local %in = (user_def => 0, user => 'root', sudoenforce => 0);
		my %o;
		acl_security_save(\%o);
		is($o{'user'},        'root', 'explicit user stored');
		is($o{'sudoenforce'},  0,     'sudoenforce=0 stored as 0');
	}

	# Falsy values normalize.
	{
		local %in = (user_def => 0, user => 'bob', sudoenforce => '');
		my %o;
		acl_security_save(\%o);
		is($o{'sudoenforce'}, 0, 'empty sudoenforce normalizes to 0');
	}
};

# Stock ACL files — `defaultacl` and `safeacl` are the templates Webmin
# applies when a new user (admin or non-admin) gets access to the module.
# Their values gate every later security check. Pin the defaults so a
# stray edit can't quietly loosen them.
subtest 'shipped ACL templates' => sub {
	my %def;
	open(my $df, '<', "$bindir/../defaultacl") or die "defaultacl: $!";
	while (<$df>) { chomp; my ($k, $v) = split(/=/, $_, 2); $def{$k} = $v; }
	close($df);
	is($def{'user'},        'root', 'defaultacl runs as root');
	is($def{'sudoenforce'}, '1',    'defaultacl has sudoenforce ON');

	my %safe;
	open(my $sf, '<', "$bindir/../safeacl") or die "safeacl: $!";
	while (<$sf>) { chomp; my ($k, $v) = split(/=/, $_, 2); $safe{$k} = $v; }
	close($sf);
	is($safe{'user'}, '*',
	   'safeacl runs as authenticated user (no root for non-admins)');
	is($safe{'noconfig'}, '1',
	   'safeacl forbids the module config screen for non-admins');
};

done_testing();
