#!/usr/bin/perl
# start.cgi
# Make the firewall active

require './shorewall6-lib.pl';
if ($access{'nochange'}) {
  &redirect("/");
  exit 0;
}

&error_setup($text{'start_err'});
$err = &run_before_apply_command();
&error($err) if ($err);
$out = &backquote_logged("$config{'shorewall6'} start 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
$err = &run_after_apply_command();
&webmin_log("start");
&redirect("");

