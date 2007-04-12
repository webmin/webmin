#!/usr/local/bin/perl
# save_routes.cgi
# Save boot-time routing configuration

require './net-lib.pl';
$access{'routes'} == 2 || &error($text{'routes_ecannot'});
&ReadParse();
&error_setup($text{'routes_err'});
&parse_routing();
&webmin_log("routes", undef, undef, \%in);
&redirect("");

