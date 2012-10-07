#!/usr/local/bin/perl
# Create, update or delete a target

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'target_err'});
my $conf = &get_iscsi_config();

# Get the target
my $target;
if ($in{'new'}) {
	$target = { 'members' => [ ] };
	}
else {
	($target) = grep { $_->{'value'} eq $in{'oldname'} }
			 &find($conf, "Target");
	$target || &error($text{'target_egone'});
	}

if ($in{'delete'}) {
	# Delete the target
	# XXX
	}
else {
	# Validate and save directives, starting with target name
	my $host;
	if ($in{'new'}) {
		$host = &find_host_name($conf) || &generate_host_name();
		}
	else {
		($host) = split(/:/, $target->{'value'});
		}
	$in{'name'} =~ /^[a-z0-9\.\_\-\]+$/i || &error($text{'target_ename'});
	$target->{'name'} = $host.":".$in{'name'};

	# Validate logical units
	# XXX

	# Validate incoming user(s)
	# XXX

	# Validate outgoing user
	# XXX

	# Save the target
	# XXX
	}
