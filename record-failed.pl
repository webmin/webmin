#!/usr/local/bin/perl
# Write an actions log for a failed login

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use WebminCore;
&init_config();
our ($remote_user);

my ($username, $reason, $remoteip, $localip) = @ARGV;
if ($username && $reason && $remoteip) {
	$ENV{'REMOTE_USER'} = $WebminCore::remote_user = $remote_user = $username;
	$0 = "miniserv.pl";
	&webmin_log("failed", undef, $reason, undef, "global", undef,
		    undef, $remoteip);
	}
