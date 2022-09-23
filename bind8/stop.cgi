#!/usr/local/bin/perl
# Stop bind 8

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'stop_ecannot'});
$access{'apply'} || &error($text{'stop_ecannot'});
$err = &stop_bind();
&error($err) if ($err);
&webmin_log("stop");
&redirect($in{'zone'} && $in{'return'} ?
	  &redirect_url($in{'type'}, $in{'zone'}, $in{'view'}) : "");

