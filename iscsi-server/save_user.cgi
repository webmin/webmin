#!/usr/local/bin/perl
# Create, update or delete a user

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in, %config);
&error_setup($text{'user_err'});
&lock_file($config{'auths_file'});
&ReadParse();

# Get the user
my $user;
if (!$in{'new'}) {
	($user) = grep { $_->{'user'} eq $in{'old'} } &list_iscsi_users();
	$user || &error($text{'user_egone'});
	}
else {
	$user = { };
	}

if ($in{'delete'}) {
	# Just remove the user
	&delete_iscsi_user($user);
	}
else {
	# Validate and store inputs
	$in{'iuser'} =~ /^[^ \t:]+$/ || &error($text{'user_euser'});
	$in{'ipass'} =~ /^[^ \t:]+$/ || &error($text{'user_epass'});
	$user->{'user'} = $in{'iuser'};
	$user->{'pass'} = $in{'ipass'};
	$user->{'mode'} = $in{'imode'};

	# Create or update the user
	if ($in{'new'}) {
		&create_iscsi_user($user);
		}
	else {
		&modify_iscsi_user($user);
		}
	}

&unlock_file($config{'auths_file'});
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'user', $user->{'user'});
&redirect("list_users.cgi");
