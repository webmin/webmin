#!/usr/local/bin/perl
# restart.cgi
# Activate the current config

require './shorewall-lib.pl';
if ($access{'nochange'}) {
  redirect("/");
  exit 0;
}

&error_setup($text{'restart_err'});
$err = &run_before_apply_command();
&error($err) if ($err);
$out = &backquote_logged("$config{'shorewall'} restart 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
$err = &run_after_apply_command();
&webmin_log("restart");
&redirect("");

