#!/usr/bin/perl
# $Id: save_zones.cgi,v 1.2 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Save zone directives to configfile

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
%access = &get_module_acl();
$access{'zones'} || &error($text{'zone_ecannot'});
&lock_all_files();

unless ($in{'new'}){  # on change or delete
	# Read current zone data from config file
	($par, $zone, $indent) = &get_branch('zone');
}

# Get values from CGI Parameters
$zonename=$in{'name'};
$zonename.='.' unless ($zonename=~m/\.$/); # Add trailing dot to zone name
$primary=$in{'primary'};
$key=$in{'key'};


# Prepare data structure
local $oldzone=$zone; # backup (necessary if name changes)
local $zone = {
	'values' => [ $zonename ],
	'comment' => $in{'desc'},
	'name' => 'zone',
	'type' => 1
};
push (@primarys, { 'name' => 'primary', 'values' => [ $primary ] });
push (@keys, { 'name' => 'key', 'values' => [ $key ] });


# Save data structure to config file

if ($in{'delete'}) {
	# Delete this zone
	&save_directive($par, [ $oldzone ], [ ], 0);
} else { # if not delete
	if ($in{'new'}) { # Add this zone
		&save_directive(&get_parent_config(), [ ], [ $zone ], 0);
	}
	else { # Update zone
		&save_directive($par, [ $oldzone ], [ ], 0); # delete old zone
		&save_directive($par, [ $oldzone ], [ $zone ], 0); # add new zone
	}
	# Add Details to that zone
	&save_directive($zone, "primary", \@primarys, 1);
	&save_directive($zone, "key", \@keys, 1);
}

&flush_file_lines();

&unlock_all_files();

&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'shared', $zone->{'values'}->[0], \%in);

&redirect("");
