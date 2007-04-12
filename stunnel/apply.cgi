#!/usr/local/bin/perl
# apply.cgi
# Restart inetd and xinetd if used

require './stunnel-lib.pl';

$err = &apply_configuration();
&error($err) if ($err);

&webmin_log("apply");
&redirect("");

