#!/usr/local/bin/perl
# Stop bind 8

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'stop_ecannot'});
$access{'apply'} || &error($text{'stop_ecannot'});
$err = &stop_bind();
&error($err) if ($err);
&webmin_log("stop");
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

