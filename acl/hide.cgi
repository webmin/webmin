#!/usr/local/bin/perl
# hide.cgi
# Remove from user's module list

require './acl-lib.pl';
&ReadParse();
%hide = map { $_, 1 } split(/\0/, $in{'hide'});
if ($in{'user'}) {
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	($user) = grep { $_->{'name'} eq $in{'user'} } &list_users();
	$user->{'modules'} = [ grep { !$hide{$_} } @{$user->{'modules'}} ];
	&modify_user($user->{'name'}, $user);
	}
else {
	$access{'groups'} || &error($text{'gedit_ecannot'});
	($group) = grep { $_->{'name'} eq $in{'group'} } &list_groups();
	$group->{'modules'} = [ grep { !$hide{$_} } @{$group->{'modules'}} ];
	&modify_group($group->{'name'}, $group);
	}
&restart_miniserv();
&redirect("");

