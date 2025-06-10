#!/usr/local/bin/perl
# Create a new active route

require './net-lib.pl';
$access{'routes'} || &error($text{'routes_ecannot'});
&ReadParse();
&error_setup($text{'routes_cerr'});

# Validate and parse inputs
$route = { };
$in{'dest_def'} || &check_ipaddress_any($in{'dest'}) ||
	&error($text{'routes_ecdest'});
$route->{'dest'} = $in{'dest_def'} ? undef : $in{'dest'};
$in{'netmask_def'} || &check_netmask($in{'netmask'},$in{'dest'}) ||
	&error($text{'routes_ecnetmask'});
if ($in{'dest_def'}) {
	$in{'netmask_def'} || &error($text{'routes_ecnetmask2'});
	}
$route->{'netmask'} = $in{'netmask_def'} ? undef : $in{'netmask'};
if ($in{'via'}) {
	# Via gateway
	&check_ipaddress_any($in{'gateway'}) || &error($text{'routes_ecgw'});
	$route->{'gateway'} = $in{'gateway'};
	}
else {
	# Local interface
	$route->{'iface'} = $in{'iface'};
	}

# Create the route
$err = &create_route($route);
&error($err) if ($err);
&webmin_log("create", "route", $route->{'dest'}, $route);
&redirect("list_routes.cgi?mode=active");

