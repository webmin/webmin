#!/usr/local/bin/perl
# Delete multiple filters at once

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'filters_derr'});

# Get them and delete them
my @d = split(/\0/, $in{'d'});
@d || &error($text{'filters_enone'});
my @filters = &list_filters();
foreach my $file (@d) {
	my ($filter) = grep { $_->[0]->{'file'} eq $file } @filters;
	next if (!$filter);
	my ($def) = grep { $_->{'name'} eq 'Definition' } @$filter;
	next if (!$def);
	&lock_file($file);
	&delete_section($file, $def);
	&unlock_file($file);
	}

&webmin_log("delete", "filters", scalar(@d));
&redirect("list_filters.cgi");
