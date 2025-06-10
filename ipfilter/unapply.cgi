#!/usr/local/bin/perl
# Just replace the config file with output from ipfstat

require './ipfilter-lib.pl';
&error_setup($text{'unapply_err'});
$err = &unapply_configuration();
&error($err) if ($err);
&webmin_log("unapply");
&redirect("");

