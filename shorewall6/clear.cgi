#!/usr/bin/perl
# clear.cgi
# Clear out all rules

require './shorewall6-lib.pl';
if ($access{'nochange'}) {
  &redirect("/");
  exit 0;
}

&error_setup($text{'clear_err'});
$out = &backquote_logged("$config{'shorewall6'} clear 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
&webmin_log("clear");
&redirect("");

