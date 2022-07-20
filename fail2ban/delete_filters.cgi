#!/usr/local/bin/perl
# Delete multiple filters at once

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'filters_derr'});

# Get them and delete them
my @d = split(/\0/, $in{'d'});
@d || &error($text{'filters_enone'});
my @filters = &list_filters();
&lock_all_config_files();
foreach my $file (@d) {
	my ($filter) = grep { $_->[0]->{'file'} eq $file } @filters;
	next if (!$filter);
	my ($def) = grep { $_->{'name'} eq 'Definition' } @$filter;
	next if (!$def);
	my @users = &find_jail_by_filter($filter);
	@users && &error(&text('filters_einuse',
			&filename_to_name($file),
			join(" ", map { $_->{'name'} } @users)));
	&delete_section($file, $def);
	}
&unlock_all_config_files();

&webmin_log("delete", "filters", scalar(@d));
&redirect("list_filters.cgi");
