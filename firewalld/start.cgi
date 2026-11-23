#!/usr/local/bin/perl
# Start up firewalld

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'start_err'});
my $err = &start_firewalld();
&error($err) if ($err);
&webmin_log("start");
# Return to the selected zone, referring page or module index
&redirect(($in{'zone'} ? "index.cgi?zone=".&urlize($in{'zone'}) :
	   &get_referer_relative()) || "");
