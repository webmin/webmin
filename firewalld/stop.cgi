#!/usr/local/bin/perl
# Shut down firewalld

use strict;
use warnings;
require './firewalld-lib.pl';
our (%text, %in);
&error_setup($text{'stop_err'});
my $err = &stop_firewalld();
&error($err) if ($err);
&webmin_log("stop");
&redirect("index.cgi?zone=".&urlize($in{'zone'}));
