#!/usr/bin/perl
# refresh.cgi
# Activate the current config

require './shorewall6-lib.pl';
if ($access{'nochange'}) {
  redirect("/");
  exit 0;
}

&error_setup($text{'refresh_err'});
$err = &run_before_apply_command();
&error($err) if ($err);
$out = &backquote_logged("$config{'shorewall6'} refresh 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
$err = &run_after_apply_command();
&webmin_log("refresh");
&redirect("");

