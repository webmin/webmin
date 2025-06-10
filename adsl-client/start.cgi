#!/usr/local/bin/perl
# start.cgi
# Start up the ADSL connection

require './adsl-client-lib.pl';
&ReadParse();
&error_setup($text{'start_err'});

$conf = &get_config();
$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
if ($?) {
	&error("<pre>$out</pre>");
	}

&ui_print_header(undef, $text{'start_title'}, "");

if (&find("CONNECT_TIMEOUT", $conf) == 0) {
	# Will try forever .. but wait for 20 secs max
	for($i=0; $i<20 && !$ip; $i++) {
		sleep(1);
		($dev, $ip) = &get_adsl_ip();
		}
	if ($ip) {
		print "<p>",&text('start_ip', "<tt>$ip</tt>"),"<p>\n";
		}
	else {
		print "<p>$text{'start_bg'}</p>\n";
		}
	}
elsif (&find("DEMAND", $conf) =~ /^\d+$/) {
	# Only starts on demand
	print "<p>$text{'start_demand'}</p>\n";
	}
else {
	# Can get the new IP
	($dev, $ip) = &get_adsl_ip();
	print "<p>",&text('start_ip', "<tt>$ip</tt>"),"<p>\n";
	}
&webmin_log("start");

&ui_print_footer("", $text{'index_return'});

