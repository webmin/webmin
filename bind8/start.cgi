#!/usr/local/bin/perl
# start.cgi
# Start bind 8
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'start_ecannot'});
$access{'apply'} || &error($text{'start_ecannot'});
my $err = &start_bind();
&error($err) if ($err);
&webmin_log("start");
&redirect($in{'zone'} && $in{'return'} ?
	  &redirect_url($in{'type'}, $in{'zone'}, $in{'view'}) : "");

