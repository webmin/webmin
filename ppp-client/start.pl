#!/usr/local/bin/perl
# Attempt a connection to the Internet with wvdial, and show the results

$no_acl_check++;
require './ppp-client-lib.pl';

&ppp_connect($config{'boot'}, 1);
exit($connected ? 0 : 1);

