#!/usr/local/bin/perl
# mgetty_apply.cgi
# Apply the current init config

require './pap-lib.pl';
$access{'mgetty'} || &error($text{'mgetty_ecannot'});
&error_setup($text{'mgetty_applyerr'});
$err = &apply_mgetty();
&error($err) if ($err);
&webmin_log("mgetty_apply");
&redirect("list_mgetty.cgi");

