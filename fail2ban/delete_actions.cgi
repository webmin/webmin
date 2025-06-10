#!/usr/local/bin/perl
# Delete multiple actions at once

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'actions_derr'});

# Get them and delete them
my @d = split(/\0/, $in{'d'});
@d || &error($text{'actions_enone'});
my @actions = &list_actions();
&lock_all_config_files();
foreach my $file (@d) {
	my ($action) = grep { $_->[0]->{'file'} eq $file } @actions;
	next if (!$action);
	my ($def) = grep { $_->{'name'} eq 'Definition' } @$action;
	next if (!$def);
	my @users = &find_jail_by_action($action);
	@users && &error(&text('actions_einuse',
			&filename_to_name($file),
			join(" ", map { $_->{'name'} } @users)));
	&delete_section($file, $def);
	}
&unlock_all_config_files();

&webmin_log("delete", "actions", scalar(@d));
&redirect("list_actions.cgi");
