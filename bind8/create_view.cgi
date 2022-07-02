#!/usr/local/bin/perl
# create_view.cgi
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %in);

require './bind8-lib.pl';
&error_setup($text{'vcreate_err'});
&ReadParse();
my $add_to_file = &add_to_file();
my $pconf = &get_config_parent($add_to_file);
my $conf = $pconf->{'members'};
$access{'views'} == 1 || &error($text{'vcreate_ecannot'});
$access{'ro'} && &error($text{'vcreate_ecannot'});

# Validate inputs
$in{'name'} =~ /^\S+$/ || &error($text{'vcreate_ename'});
my @views = &find("view", $conf);
foreach my $v (@views) {
	&error($text{'vcreate_etaken'}) if ($v->{'value'} eq $in{'name'});
	}
$in{'class_def'} || $in{'class'} =~ /^[A-Za-z0-9]+$/ ||
	&error($text{'vcreate_eclass'});

# Create the view
&lock_file(&make_chroot($add_to_file));
my $dir = { 'name' => 'view',
	 'values' => [ $in{'name'}, $in{'class_def'} ? ( ) : ( $in{'class'} ) ],
	 'type' => 1,
	 'members' => [ ],
	 'file' => $add_to_file
	};
if (!$in{'match_def'}) {
	push(@{$dir->{'members'}}, { 'name' => 'match-clients',
				     'type' => 1,
				     'members' =>
		[ map { { 'name' => $_ } } split(/\s+/, $in{'match'}) ] } );
	}
&save_directive($pconf, undef, [ $dir ], 0);
&flush_file_lines();
&unlock_file(&make_chroot($add_to_file));

# Add to user's ACL
if (!&can_edit_view($dir)) {
	$access{'vlist'} = join(" ", &unique(
                                split(/\s+/, $access{'vlist'}), $in{'name'}));
	&save_module_acl(\%access);
	}
&webmin_log("create", "view", $in{'name'}, \%in);
&redirect("");

