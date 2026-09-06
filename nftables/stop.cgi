#!/usr/bin/perl
# stop.cgi
# Stop the system nftables service

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%text);
error_setup($text{'stop_err'});
assert_acl('service');
nftables_service_status() || error($text{'bootup_eservice'});

my $err = stop_nftables_service();
error($err) if ($err);

webmin_log("stop");
redirect("index.cgi");
