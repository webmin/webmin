#!/usr/local/bin/perl
# start.cgi
# Start bind 8
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'start_ecannot'});
$access{'apply'} || &error($text{'start_ecannot'});
my $err = &start_bind();
&error($err) if ($err);
&webmin_log("start");
my $redir_targ = ($in{'type'} eq "master" ? "edit_master.cgi" :
		  $in{'type'} eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi");
my $zone;
if ($in{'zone'}) {
	$zone = "?zone=$in{'zone'}";
	if ($in{'view'}) {
		$zone .= "&view=$in{'view'}";
		}
	}
&redirect($zone && $in{'return'} ? "$redir_targ$zone" : "");

