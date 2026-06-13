#!/usr/local/bin/perl
# Reload a user's systemd manager after user unit-file changes.

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %in, %text);

ReadParse();
error_setup($text{'reload_user_err'});

my $user = clean_unit_value($in{'user'});
my $uinfo = $user ? get_user_details($user) : undef;
$uinfo || error($text{'systemd_euser'});
systemd_can_reload_user(\%access, $uinfo->{'user'}) ||
	systemd_acl_error('pmanual_user');

ui_print_unbuffered_header(undef, $text{'reload_user_title'}, "");

print text('reload_user_doing',
	   ui_tag('tt', html_escape($uinfo->{'user'}))), ui_br(), "\n";
my ($ok, $out) = reload_user_manager($uinfo->{'user'});
print ui_tag('pre', html_escape($out)) if ($out);
print($ok ? $text{'mass_ok'} : $text{'mass_failed'}, ui_p());
if ($ok) {
	mark_user_daemon_reloaded($uinfo->{'user'});
	webmin_log("reload", "systemd-user", $uinfo->{'user'},
		   { 'user' => $uinfo->{'user'} });
	}

ui_print_footer("index.cgi?scope=user&unituser=".urlize($uinfo->{'user'}),
		$text{'index_return'});
