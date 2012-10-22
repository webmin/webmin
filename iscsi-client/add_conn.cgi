#!/usr/local/bin/perl
# Actually add a connection

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'add_err'});

# Re-check the list of targets
my $targets = &list_iscsi_targets($in{'host'}, $in{'port'}, $in{'iface'});
ref($targets) || &error(&text('add_etargets', $in{'host'}, $targets));
my $target = undef;
if ($in{'target'}) {
	($target) = grep { $_->{'name'}.":".$_->{'target'} eq $in{'target'} }
			 @$targets;
	$target || &error(&text('add_etarget', $in{'target'}));
	}

# Validate username and password
my @auth;
if (!$in{'auth_def'}) {
	$in{'authuser'} =~ /\S/ || &error($text{'auth_eusername'});
	$in{'authpass'} =~ /\S/ || &error($text{'auth_epassword'});
	@auth = ( $in{'authmethod'}, $in{'authuser'}, $in{'authpass'} );
	}

# Try to make the connection
my $err = &create_iscsi_connection($in{'host'}, $in{'port'},
				   $in{'iface'}, $target, @auth);
&error($err) if ($err);

&webmin_log("add", "connection", $in{'host'},
	    { 'host' => $in{'host'},
	      'port' => $in{'port'},
	      'target' => $target->{'target'} });
&redirect("list_conns.cgi");
