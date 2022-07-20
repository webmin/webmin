#!/usr/local/bin/perl
# convert_master.cgi
# Convert a master zone into a slave
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %in, %config);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'convert_err'});

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $zconf = &zone_to_config($zone);

$access{'slave'} || &error($text{'screate_ecannot1'});
&lock_file(&make_chroot($zconf->{'file'}));

# Change the type directive
&save_directive($zconf, 'type', [ { 'name' => 'type',
				    'values' => [ 'slave' ] } ], 1);

# Add a masters section
if ($config{'default_master'}) {
	my @mdirs = map { { 'name' => $_ } } split(/\s+/, $config{'default_master'});
	&save_directive($zconf, 'masters', [ { 'name' => 'masters',
					       'type' => 1,
					       'members' => \@mdirs } ], 1);
	}

# Take out directives not allowed in slaves
&save_directive($zconf, 'allow-update', [ ], 1);

&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));
&redirect("");

