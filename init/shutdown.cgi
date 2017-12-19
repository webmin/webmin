#!/usr/local/bin/perl
# shutdown.cgi
# Shutdown the system immediately..

require './init-lib.pl';
&ReadParse();
$access{'shutdown'} || &error($text{'shutdown_ecannot'});
&ui_print_header(undef, $text{'shutdown_title'}, "");

$ttcmd = "<tt>".&html_escape($config{'shutdown_command'})."</tt>";
if ($in{'confirm'}) {
	print &ui_subheading(&text('shutdown_exec', $ttcmd));
	&shutdown_system();
	&webmin_log("shutdown");
	}
else {
	print &ui_confirmation_form(
		"shutdown.cgi",
		&text('shutdown_rusure', $ttcmd),
		undef,
		[ [ "confirm", $text{'shutdown_ok'} ] ]);
	}
&ui_print_footer("", $text{'index_return'});

