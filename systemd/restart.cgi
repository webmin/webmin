#!/usr/local/bin/perl
# Reload the system systemd manager after unit-file changes.

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %text);

ReadParse();
error_setup($text{'reload_err'});
systemd_can_reload(\%access) || systemd_acl_error('preload');

ui_print_unbuffered_header(undef, $text{'reload_title'}, "");

# Run daemon-reload directly so command output can be shown to the admin.
my $systemctl = has_command("systemctl");
$systemctl || error($text{'systemd_esystemctl'});
print $text{'reload_doing'}, ui_br(), "\n";
my $out = backquote_logged(
	quotemeta($systemctl)." daemon-reload 2>&1 </dev/null");
my $ok = !$?;
print ui_tag('pre', html_escape($out)) if ($out);
print($ok ? $text{'mass_ok'} : $text{'mass_failed'}, ui_p());
if ($ok) {
	mark_daemon_reloaded();
	webmin_log("reload", "systemd");
	}

ui_print_footer("index.cgi", $text{'index_return'});
