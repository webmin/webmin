# Common functions for the xterm module

BEGIN { push(@INC, ".."); };    ## no critic
use WebminCore;
use strict;
use warnings;
no warnings 'uninitialized';
our (%access, %config);
init_config();
%access = get_module_acl();

# config_pre_load(mod-info-ref, [mod-order-ref])
# Check if some config options are conditional,
# and if not allowed, remove them from listing
sub config_pre_load
{
my ($modconf_info, $modconf_order) = @_;
if (($ENV{'HTTP_X_REQUESTED_WITH'} || '') eq "XMLHttpRequest") {
	# Size is not supported in Authentic, because resize works flawlessly
	# and making it work would just add addition complexity for no good
	# reason
	delete($modconf_info->{'size'}) if (ref($modconf_info) eq 'HASH');
	@{$modconf_order} = grep { $_ ne 'size' } @{$modconf_order}
		if (ref($modconf_order) eq 'ARRAY');
	}
}

# verify_websocket_key(client-key, session-id)
# Returns 1 if the client's Sec-WebSocket-Key matches the base64-encoded
# session ID, 0 otherwise. miniserv.pl rewrites the inbound handshake key
# to base64(session_id) before forwarding the upgrade to the shell server,
# so equality proves the connection came through the authenticated proxy
# and is bound to this Webmin session.
sub verify_websocket_key
{
my ($key, $sess) = @_;
return 0 if (!defined($key) || !defined($sess) || $sess eq '');
require MIME::Base64;
my $dsess = MIME::Base64::encode_base64($sess);
$key   =~ s/\s//g;
$dsess =~ s/\s//g;
return 0 if ($key eq '' || $dsess eq '');
return $key eq $dsess ? 1 : 0;
}

# parse_resize_message(message)
# If $message is the resize signal that xterm.js sends on terminal resize
# (literal backslash-zero-three-three then "[8;(rows);(cols)t"), return
# (rows, cols) as integers. Otherwise return an empty list. The format is
# a custom out-of-band signal — not a real ANSI escape — so anything else
# is treated as regular keyboard input and forwarded to the shell.
sub parse_resize_message
{
my ($msg) = @_;
return () if (!defined($msg));
if ($msg =~ /^\\033\[8;\((\d+)\);\((\d+)\)t\z/) {
	return ($1 + 0, $2 + 0);
	}
return ();
}

# resolve_shell_user(\%access, $remote_user, \%in, \%config)
# Decide which Unix account the terminal will run as, given the module ACL
# (%access), the Webmin-authenticated user, the CGI input (%in, which may
# carry a 'user' override) and the module config (%config). Pure function:
# does no I/O beyond getpwnam() for the sudoenforce branch. The caller
# must still validate the result against getpwnam() before exec'ing a shell.
#
# Rules (preserved verbatim from the previous inline version in index.cgi):
#   - access user "*" → start from $remote_user.
#   - else, access user "root" with sudoenforce !=0 AND no explicit
#     in{user} AND remote_user differs from "root" → prefer remote_user
#     when it has a local home dir (sudo-preferred path).
#   - config{user} can override a remaining "root" choice.
#   - if the resolved user is still "root" AND in{user} is set, in{user}
#     overrides — the admin explicitly allowed root, so any user is OK.
# Note the trailing in{user} branch runs regardless of how $user got to
# "root", so e.g. access="*" with remote_user="root" can still be
# overridden by in{user}. That's preserved here for compatibility; an
# operator who wants in{user} ignored for "*" should ensure the
# authenticated user isn't root.
sub resolve_shell_user
{
my ($access, $remote_user, $in, $config) = @_;
$in     ||= {};
$config ||= {};
my $user = $access->{'user'};
return if (!defined($user) || $user eq '');
if ($user eq "*") {
	$user = $remote_user;
	}
elsif ($user eq "root" && $remote_user ne $user && !$in->{'user'} &&
       (defined($access->{'sudoenforce'}) ? $access->{'sudoenforce'} : '') ne '0') {
	my @uinfo = getpwnam($remote_user);
	if (@uinfo && $uinfo[7]) {
		$user = $remote_user;
		}
	}
$user = $config->{'user'} if ($user eq 'root' && $config->{'user'});
if ($user eq "root" && defined($in->{'user'}) && $in->{'user'} ne '') {
	$user = $in->{'user'};
	}
return $user;
}

1;