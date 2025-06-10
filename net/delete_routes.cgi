#!/usr/local/bin/perl
# Deletes several active routes

require './net-lib.pl';
$access{'routes'} || &error($text{'routes_ecannot'});
&ReadParse();
&error_setup($text{'routes_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'routes_denone'});

@routes = &list_routes();
foreach $d (sort { $b <=> $a } @d) {
	$err = &delete_route($routes[$d]);
	&error($err) if ($err);
	}
&webmin_log("delete", "routes", scalar(@d));
&redirect("list_routes.cgi?mode=active");
