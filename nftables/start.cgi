#!/usr/bin/perl
# start.cgi
# Start the system nftables service

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%text);
error_setup($text{'start_err'});
assert_acl('service');
nftables_service_status() || error($text{'bootup_eservice'});

my $err = start_nftables_service();
error($err) if ($err);

webmin_log("start");
redirect("index.cgi");
