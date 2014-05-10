#!/usr/local/bin/perl
# Create, update or delete a jail

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'jail_err'});

my $jail;
my @jails = &list_jails();

if ($in{'new'}) {
	# Create new jail object
	$jail = { 'members' => [ ],
		  'file' => "$config{'config_dir'}/jail.conf" };
	}
else {
	# Find existing jail
	($jail) = grep { $_->{'name'} eq $in{'name'} } @jails;
	$jail || &error($text{'jail_egone'});
	}

if ($in{'delete'}) {
	# Just delete the jail
	&lock_file($jail->{'file'});
	&delete_section($jail->{'file'}, $jail);
	&unlock_file($jail->{'file'});
	}
else {
	# Validate inputs
	my $file;
	$in{'name'} =~ /^[a-z0-9\_\-]+$/i || &error($text{'jail_ename'});
	$jail->{'name'} = $in{'name'};
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		# Check for clash
		my ($clash) = grep { $_->{'name'} eq $in{'name'} } @jails;
		$clash && &error($text{'jail_eclash'});
		}

	# Parse and validate actions
	my @actions;
	for(my $i=0; defined($in{"action_$i"}); $i++) {
		next if (!$in{"action_$i"});
		my @opts;
		if ($in{"name_$i"}) {
			$in{"name_$i"} =~ /^[A-Za-z0-9\.\_\-]+$/ ||
				&error(&text('jail_eaname', $i+1));
			push(@opts, "name=".$in{"name_$i"});
			}
		if ($in{"port_$i"}) {
			$in{"port_$i"} =~ /^\d+$/ ||
			    getservbyname($in{"port_$i"},
					  $in{"protocol_$i"} || "tcp") ||
				&error(&text('jail_eport', $i+1));
			push(@opts, "port=".$in{"port_$i"});
			}
		if ($in{"protocol_$i"}) {
			push(@opts, "protocol=".$in{"protocol_$i"});
			}
		push(@opts, split(/\s+/, $in{"others_$i"}));
		push(@actions, $in{"action_$i"}."[".join(", ", @opts)."]");
		}
	@actions || &error($text{'jail_eactions'});

	# Split and validate log file paths
	my @logpaths = split(/\r?\n/, $in{'logpath'});
	@logpaths || &error($text{'jail_elogpaths'});
	foreach my $l (@logpaths) {
		$l =~ /^\/\S+$/ || &error($text{'jail_elogpath'});
		}

	# Create new section or rename existing if needed
	&lock_file($jail->{'file'});
	if ($in{'new'}) {
		&create_section($jail->{'file'}, $jail);
		}
	elsif ($in{'name'} ne $in{'old'}) {
		&modify_section($jail->{'file'}, $jail);
		}

	# Save directives within the section
	&save_directive("enabled", $in{'enabled'} ? 'true' : 'false', $jail);
	&save_directive("filter", $in{'filter'}, $jail);
	&save_directive("action", join("\n", @actions), $jail);
	&save_directive("logpath", join("\n", @logpaths), $jail);

	&unlock_file($jail->{'file'});
	}

# Log and redirect
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'jail', $jail->{'name'});
&redirect("list_jails.cgi");
