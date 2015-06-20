#!/usr/local/bin/perl
# Activate all saved firewalld rules

use strict;
use warnings;
require './firewalld-lib.pl';
our (%text, %in);
&error_setup($text{'restart_err'});
my $err = &apply_firewalld();
&error($err) if ($err);
&webmin_log("restart");
&redirect("index.cgi?zone=".&urlize($in{'zone'}));
