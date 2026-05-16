#!/usr/bin/perl
# search_services.cgi
# Return matching quick service definitions for the autocomplete widget

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in);
ReadParse();
assert_quick_acl('service');

my $limit = $in{'limit'} || 20;
$limit = 20 if ($limit !~ /^\d+$/);
my @services = search_quick_services($in{'q'}, $limit);
my @results = map {
	{
		'id' => $_->{'id'},
		'label' => $_->{'label'} || $_->{'id'},
	}
} @services;

print_json(\@results);
