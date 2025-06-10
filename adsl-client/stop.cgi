#!/usr/local/bin/perl
# stop.cgi
# Shut down the ADSL connection

require './adsl-client-lib.pl';
&ReadParse();
&error_setup($text{'stop_err'});

$out = &backquote_logged("$config{'stop_cmd'} 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
else {
	&ui_print_header(undef, $text{'stop_title'}, "");

	# Wait for it to really stop
	for($i=0; $i<20 && $ip; $i++) {
		sleep(1);
		($dev, $ip) = &get_adsl_ip();
		}
	if ($ip) {
		print "<p>$text{'stop_failed'}<p>\n";
		}
	else {
		print "<p>$text{'stop_ok'}<p>\n";
		}

	&ui_print_footer("", $text{'index_return'});
	}
&webmin_log("stop");

