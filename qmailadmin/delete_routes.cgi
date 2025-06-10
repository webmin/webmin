#!/usr/local/bin/perl
# Delete a bunch of domain routes

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'rdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});

@routes = &list_routes();
foreach $d (@d) {
	($route) = grep { $_->{'from'} eq $d } @routes;
	if ($route) {
		&delete_route($route);
		}
	}
&webmin_log("delete", "routes", scalar(@d));
&redirect("list_routes.cgi");

