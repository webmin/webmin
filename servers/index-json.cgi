#!/usr/local/bin/perl
# Return a list of other Webmin servers as JSON

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';

# The navigation menu needs labels and IDs, never saved logins or file paths.
my @servers = map {
	my $server = $_;
	+{ map { $_ => $server->{$_} } qw(id host desc) }
	} &list_servers_sorted(1);
print_json(\@servers);
