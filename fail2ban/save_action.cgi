#!/usr/local/bin/perl
# Create, update or delete a action

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'action_err'});

my ($action, $def);
if ($in{'new'}) {
	# Create new action object
	$def = { 'name' => 'Definition',
		 'members' => [ ] };
	$action = [ $def ];
	}
else {
	# Find existing action
	($action) = grep { $_->[0]->{'file'} eq $in{'file'} } &list_actions();
	$action || &error($text{'action_egone'});
	($def) = grep { $_->{'name'} eq 'Definition' } @$action;
	$def || &error($text{'action_edefgone'});
	}

my $file = $in{'file'};
if ($in{'delete'}) {
	# Just delete the action
	my @users = &find_jail_by_action($action);
	@users && &error(&text('action_einuse',
			join(" ", map { $_->{'name'} } @users)));
	&lock_all_config_files();
	&delete_section($file, $def);
	&unlock_all_config_files();
	}
else {
	# Validate inputs
	my $file;
	if ($in{'new'}) {
		$in{'name'} =~ /^[a-z0-9\_\-]+$/i ||
			&error($text{'action_ename'});
		$file = "$config{'config_dir'}/action.d/$in{'name'}.conf";
		-r $file && &error($text{'action_eclash'});
		}

	# Create new section if needed
	&lock_all_config_files();
	if ($in{'new'}) {
		&create_section($file, $def);
		}

	# Save directives within the section
	$in{'start'} =~ s/\r//g;
	&save_directive("actionstart", $in{'start'}, $def);
	$in{'stop'} =~ s/\r//g;
	&save_directive("actionstop", $in{'stop'}, $def);
	$in{'check'} =~ s/\r//g;
	&save_directive("actioncheck", $in{'check'}, $def);
	$in{'ban'} =~ s/\r//g;
	&save_directive("actionban", $in{'ban'}, $def);
	$in{'unban'} =~ s/\r//g;
	&save_directive("actionunban", $in{'unban'}, $def);

	&unlock_all_config_files();
	}

# Log and redirect
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'action', &filename_to_name($file));
&redirect("list_actions.cgi");
