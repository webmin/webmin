#!/usr/local/bin/perl
# stop.cgi
# Shut down the firewall

require './shorewall-lib.pl';
if ($access{'nochange'}) {
  &redirect("/");
  exit 0;
}

&error_setup($text{'stop_err'});
$out = &backquote_logged("$config{'shorewall'} stop 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
&webmin_log("stop");
&redirect("");

