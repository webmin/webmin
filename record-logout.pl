#!/usr/local/bin/perl
# Write an actions log for a logout

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
our ($remote_user);

&init_config();
my ($username, $sid, $remoteip, $localip) = @ARGV;
if ($username && $sid && $remoteip) {
	$WebminCore::remote_user = $remote_user = $username;
	$main::session_id = $sid;
	$0 = "miniserv.pl";
	&webmin_log("logout", undef, undef, undef, "global", undef,
		    undef, $remoteip);
	}
