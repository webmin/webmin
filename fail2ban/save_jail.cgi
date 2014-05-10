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
	# XXX validate other fields

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

	&unlock_file($jail->{'file'});
	}

# Log and redirect
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'jail', $jail->{'name'});
&redirect("list_jails.cgi");
