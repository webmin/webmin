#!/usr/local/bin/perl
# Write an actions log for a login

BEGIN { push(@INC, "."); };
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use WebminCore;
our ($remote_user);

&init_config();
my ($username, $sid, $remoteip, $localip) = @ARGV;
if ($username && $sid && $remoteip) {
	$ENV{'REMOTE_USER'} = $WebminCore::remote_user = $remote_user = $username;
	$main::session_id = $sid;
	$0 = "miniserv.pl";
	&webmin_log("login", undef, undef, undef, "global", undef,
		    undef, $remoteip);
	}
