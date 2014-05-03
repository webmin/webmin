#!/usr/local/bin/perl
# Create, update or delete a filter

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParse();
&error_setup($text{'filter_err'});

if ($in{'new'}) {
	# Find existing filter
	($filter) = grep { $_->[0]->{'file'} eq $in{'file'} } &list_filters();
	$filter || &error($text{'filter_egone'});
	($def) = grep { $_->{'name'} eq 'Definition' } @$filter;
	$def || &error($text{'filter_edefgone'});
	}
else {
	# Create new filter object
	$dir = { 'members' => [ ] };
	$filter = [ $dir ];
	}

if ($in{'delete'}) {
	# Just delete the filter
	&lock_file($in{'file'});
	&delete_section($dir);
	&unlock_file($in{'file'});
	}
else {
	# Validate inputs

	# Update or create
	}

# Log and redirect
# XXX
