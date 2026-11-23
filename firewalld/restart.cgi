#!/usr/local/bin/perl
# Activate all saved firewalld rules

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'restart_err'});
my $err = &apply_firewalld();
&error($err) if ($err);
&webmin_log("restart");
# Return to the selected zone, referring page or module index
&redirect(($in{'zone'} ? "index.cgi?zone=".&urlize($in{'zone'}) :
	   &get_referer_relative()) || "");
