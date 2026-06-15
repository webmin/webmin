#!/usr/local/bin/perl
# Toggle linger for a systemd user manager

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %in, %text);

# This page is reached from the index linger toggle links.
error_setup($text{'systemd_linger_err'});
ReadParse();

# Validate the requested user and linger state before calling loginctl.
my $user = clean_unit_value($in{'user'});
my $enabled = $in{'enabled'};
get_user_details($user) || error($text{'systemd_euser'});
systemd_can_linger(\%access, $user) || systemd_acl_error('plinger');
if (!defined($enabled) || ($enabled ne '0' && $enabled ne '1')) {
	error($text{'systemd_elinger'});
	}
$enabled = $enabled eq '1' ? 1 : 0;

# Apply the requested linger state through loginctl.
my ($ok, $out) = set_user_linger($user, $enabled);
$ok || error_linger_command($user, $out);

# Enabling linger should also bring up the user manager immediately.
if ($enabled) {
	($ok, $out) = start_user_manager($user);
	$ok || error_linger_command($user, $out);
	}

# Record the change and return to the User units tab for the same owner.
webmin_log("linger", "systemd-user", $user,
	    { 'user' => $user, 'enabled' => $enabled });
redirect(index_url(undef, 1, $user));

# error_linger_command(user, output)
# Shows escaped loginctl or systemctl output from a failed operation.
sub error_linger_command
{
my ($user, $out) = @_;
$out ||= $text{'systemd_euser'};

# Show command output as escaped preformatted text for easier diagnosis.
error(text('systemd_eusercmd',
	     ui_tag('tt', html_escape($user)),
	     ui_tag('pre', html_escape($out))));
}
