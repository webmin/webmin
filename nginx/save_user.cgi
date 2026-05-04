#!/usr/local/bin/perl
# Create, update or delete a user

use strict;
use warnings;
require './nginx-lib.pl';
&foreign_require("htaccess-htpasswd");
our (%text, %in, %access);
&ReadParse();
&error_setup($text{'user_err'});
$in{'file'} || &error($text{'users_efile'});

# Get the user being edited
&lock_file($in{'file'});
&switch_write_user(1);
my $users = &htaccess_htpasswd::list_users($in{'file'});
my $user;
if (!$in{'new'}) {
	($user) = grep { $_->{'user'} eq $in{'old'} } @$users;
        $user || &error($text{'user_egone'});
	}
else {
	$user = { };
	}

if ($in{'delete'}) {
	# Just delete him
	&htaccess_htpasswd::delete_user($user);
	}
else {
	# Validate inputs
	$in{'htuser'} || &error($htaccess_htpasswd::text{'save_euser1'});
	$in{'htuser'} =~ /:/ && &error($htaccess_htpasswd::text{'save_euser2'});
	$user->{'user'} = $in{'htuser'};

	if (!$in{'htpass_def'}) {
		$user->{'pass'} = &htaccess_htpasswd::encrypt_password(
					$in{'htpass'});
		}

	$user->{'enabled'} = $in{'enabled'};

	# Create or update user
	if ($in{'new'}) {
		&htaccess_htpasswd::create_user($user, $in{'file'});
		}
	else {
		&htaccess_htpasswd::modify_user($user);
		}
	}
&switch_write_user(0);

&unlock_file($in{'file'});
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "user", $user->{'user'}, { 'file' => $in{'file'} });
&redirect("list_users.cgi?file=".&urlize($in{'file'}).
	  "&id=".&urlize($in{'id'})."&path=".&urlize($in{'path'}));

