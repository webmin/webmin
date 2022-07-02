#!/usr/local/bin/perl
# Delete a bunch of Webmin users, or add them to a group

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ReadParse();
&error_setup($in{'joingroup'} ? $text{'udeletes_jerr'} : $text{'udeletes_err'});

# Validate inputs
my @d = split(/\0/, $in{'d'});
@d || &error($text{'udeletes_enone'});
foreach my $user (@d) {
	&can_edit_user($user) || &error($text{'delete_euser'});
	if ($base_remote_user eq $user && !$in{'joingroup'}) {
		&error($text{'delete_eself'});
		}
	&used_for_anonymous($user) && &error($text{'delete_eanonuser'});
	my $uinfo = &get_user($user);
	$uinfo->{'readonly'} && &error($text{'udeletes_ereadonly'});
	}

if ($in{'joingroup'}) {
	# Add users to a group
	my $newgroup = &get_group($in{'group'});
	if ($access{'gassign'} ne '*') {
		my @gcan = split(/\s+/, $access{'gassign'});
		&indexof($in{'group'}, @gcan) >= 0 ||
			&error($text{'save_egroup'});
		}
	foreach my $user (@d) {
		my $uinfo = &get_user($user);
		next if (!$uinfo);
		next if ($newgroup &&
			 &indexof($user, @{$newgroup->{'members'}}) >= 0);

		# Remove from old group, if any
		my $oldgroup = &get_users_group($user);
		if ($oldgroup) {
			$oldgroup->{'members'} =
				[ grep { $_ ne $user }
				  @{$oldgroup->{'members'}} ];
			&modify_group($oldgroup->{'name'}, $oldgroup);
			}

		# Add to new group
		push(@{$newgroup->{'members'}}, $user);
		&modify_group($newgroup->{'name'}, $newgroup);

		my @mods = @{$uinfo->{'modules'}};
		if ($oldgroup) {
			# Remove modules from the old group
			@mods = grep { &indexof($_, @{$oldgroup->{'modules'}})
				       < 0 } @mods;
			}

		if ($newgroup) {
			# Add modules from group to list
			my @ownmods;
			foreach my $m (@mods) {
				push(@ownmods, $m) if (&indexof($m,
					@{$newgroup->{'modules'}}) < 0);
				}
			@mods = &unique(@mods, @{$newgroup->{'modules'}});
			$uinfo->{'ownmods'} = \@ownmods;

			# Copy ACL files for group
			&copy_group_user_acl_files($in{'group'}, $user,
				      [ @{$newgroup->{'modules'}}, "" ]);
			}
		$uinfo->{'modules'} = \@mods;

		# Save the user
		&modify_user($user, $uinfo);
		}

	&webmin_log("joingroup", "users", scalar(@d),
		    { 'group' => $in{'group'} });
	&redirect("");
	}
elsif ($in{'confirm'}) {
	# Do it
	$access{'delete'} || &error($text{'delete_ecannot'});
	foreach my $user (@d) {
		&delete_user($user);
		&delete_from_groups($user);
		}

	&reload_miniserv();
	&webmin_log("delete", "users", scalar(@d));
	&redirect("");
	}
else {
	# Ask the user if he is sure
	$access{'delete'} || &error($text{'delete_ecannot'});
	&ui_print_header(undef, $text{'udeletes_title'}, "");

	print &ui_confirmation_form(
		"delete_users.cgi",
		&text('udeletes_rusure', scalar(@d)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'udeletes_ok'} ] ],
		&text('udeletes_users', join(" ", map { "<tt>$_</tt>" } @d)),
		);
	print "</center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

