#!/usr/local/bin/perl
# restart.cgi
# Restart the running named
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'restart_ecannot'});
$access{'apply'} == 1 || $access{'apply'} == 3 ||
	&error($text{'restart_ecannot'});
&error_setup($text{'restart_err'});
my $err = &restart_bind();
&error($err) if ($err);

if ($access{'remote'}) {
	# Restart all slaves too
	&error_setup();
	my @slaveerrs = &restart_on_slaves();
	if (@slaveerrs) {
		&error(&text('restart_errslave',
		     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				      	    @slaveerrs)));
		}
	}

&webmin_log("apply");
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

