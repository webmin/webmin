#!/usr/local/bin/perl
# disconnect.cgi
# Shut down a connection by killing it's PID

require './ppp-client-lib.pl';
&error_setup($text{'disc_err'});
&ReadParse();

&ui_print_header(undef, $text{'disc_title'}, "");

if ($in{'mode'} == 0) {
	($ip, $pid, $sect) = &get_connect_details();
	}
&ppp_disconnect($in{'mode'}, 0);

&webmin_log("disconnect", $sect);
&ui_print_footer("", $text{'index_return'});

