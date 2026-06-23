#!/usr/local/bin/perl
# Save a raw systemd unit file selected by edit_manual.cgi.

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %in, %text);

ReadParseMime();
error_setup($text{'manual_err'});

# The posted path must still be in the discovered allowlist at save time.
my $info = manual_unit_file($in{'file'});
$info || error($text{'manual_efile'});
systemd_can_manual($info) ||
	systemd_acl_error($info->{'scope'} eq 'user' ?
			  'pmanual_user' : 'pmanual');
my ($ok, $err) = write_manual_unit_file($info, $in{'data'});
$ok || error($err || $text{'manual_ewrite'});

# User-unit edits include the owner so the log parser can render context.
if ($info->{'scope'} eq 'user') {
	mark_user_units_changed($info->{'user'});
	webmin_log("manual", "systemd-user", $info->{'file'},
		    { 'user' => $info->{'user'} });
	redirect("index.cgi?scope=user&unituser=".urlize($info->{'user'}));
	}
else {
	mark_units_changed();
	webmin_log("manual", "systemd", $info->{'file'});
	redirect("");
	}
