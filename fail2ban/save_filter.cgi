#!/usr/local/bin/perl
# Create, update or delete a filter

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'filter_err'});

my ($filter, $def);
if ($in{'new'}) {
	# Create new filter object
	$def = { 'name' => 'Definition',
		 'members' => [ ] };
	$filter = [ $def ];
	}
else {
	# Find existing filter
	($filter) = grep { $_->[0]->{'file'} eq $in{'file'} } &list_filters();
	$filter || &error($text{'filter_egone'});
	($def) = grep { $_->{'name'} eq 'Definition' } @$filter;
	$def || &error($text{'filter_edefgone'});
	}

my $file = $in{'file'};
if ($in{'delete'}) {
	# Just delete the filter
	my @users = &find_jail_by_filter($filter);
	@users && &error(&text('filter_einuse',
			join(" ", map { $_->{'name'} } @users)));
	&lock_all_config_files();
	&delete_section($file, $def);
	&unlock_all_config_files();
	}
else {
	# Validate inputs
	my $file;
	if ($in{'new'}) {
		$in{'name'} =~ /^[a-z0-9\_\-]+$/i ||
			&error($text{'filter_ename'});
		$file = "$config{'config_dir'}/filter.d/$in{'name'}.conf";
		-r $file && &error($text{'filter_eclash'});
		}
	$in{'fail'} =~ /\S/ || &error($text{'filter_efail'});

	# Create new section if needed
	&lock_all_config_files();
	if ($in{'new'}) {
		&create_section($file, $def);
		}

	# Save directives within the section
	$in{'fail'} =~ s/\r//g;
	&save_directive("failregex", $in{'fail'}, $def);
	$in{'ignore'} =~ s/\r//g;
	&save_directive("ignoreregex", $in{'ignore'}, $def);

	&unlock_all_config_files();
	}

# Log and redirect
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'filter', &filename_to_name($file));
&redirect("list_filters.cgi");
