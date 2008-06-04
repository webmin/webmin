#!/usr/bin/perl
# restart_mountd.cgi
# Do whatever is needed to apply changes to the exports file

require './exports-lib.pl';
&error_setup($text{'restart_err'});
$err = &restart_mountd();
&error($err) if ($err);
&webmin_log('apply');
&redirect("");
