#!/usr/local/bin/perl
# Delete multiple users

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text, %in, %config);
&error_setup($text{'dusers_err'});
&lock_file($config{'auths_file'});
&ReadParse();

# Get the users
my @users = &list_iscsi_users();
my @delusers;
foreach my $d (split(/\0/, $in{'d'})) {
	my ($user) = grep { $_->{'user'} eq $d } @users;
	if ($user) {
		push(@delusers, $user);
		}
	}
@delusers || &error($text{'dusers_enone'});

# Delete them, in reverse line order
foreach my $user (sort { $b->{'line'} cmp $a->{'line'} } @delusers) {
	&delete_iscsi_user($user);
	}

&unlock_file($config{'auths_file'});
if (@delusers == 1) {
	&webmin_log("delete", "user", $delusers[0]->{'user'});
	}
else {
	&webmin_log("delete", "users", scalar(@delusers));
	}
&redirect("list_users.cgi");
