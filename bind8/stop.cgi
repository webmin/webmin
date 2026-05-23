#!/usr/local/bin/perl
# Stop bind 8
use strict;
use warnings;
no warnings 'uninitialized';

require './bind8-lib.pl';    ## no critic
our (%access, %text, %in);
&ReadParse();
$access{'ro'} && &error($text{'stop_ecannot'});
$access{'apply'} || &error($text{'stop_ecannot'});
my $err = &stop_bind();
&error($err) if ($err);
&webmin_log("stop");
&redirect($in{'zone'} && $in{'return'} ?
	  &redirect_url($in{'type'}, $in{'zone'}, $in{'view'}) : "");

