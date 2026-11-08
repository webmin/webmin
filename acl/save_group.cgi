#!/usr/local/bin/perl
# save_group.cgi
# Create, modify or delete a webmin group

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';    ## no critic
our (%in, %text, %config, %access, $config_directory, $base_remote_user);
&ReadParse();
# Only permission editors may change global ACLs, including API-only access.
if ($in{'acl_security_form'} && !$access{'acl'}) {
	&error($text{'acl_emod'});
	}
$access{'groups'} || &error($text{'gedit_ecannot'});

# Check for special button clicks, and redirect
if ($in{'but_clone'}) {
	&redirect("edit_group.cgi?clone=".&urlize($in{'old'}));
	exit;
	}
elsif ($in{'but_delete'}) {
	&redirect("delete_group.cgi?group=".&urlize($in{'old'}));
	exit;
	}

# Find logged-in webmin user
my @ulist = &list_users();
my ($me) = grep { $_->{'name'} eq $base_remote_user } @ulist;

my (%group, $old);
if ($in{'old'}) {
	# Get the original group
	$old = &get_group($in{'old'});
	$old || &error($text{'gedit_egone'});
	$group{'members'} = $old->{'members'};
	$group{'proto'} = $old->{'proto'};
	$group{'id'} = $old->{'id'};
	}
&error_setup($text{'gsave_err'});

# Validate global permissions before changing the group or its members' ACLs.
my %global_access;
if ($in{'old'} && $in{'acl_security_form'}) {
	&foreign_require("", "acl_security.pl");
	&foreign_call("", "acl_security_save", \%global_access, \%in);
	}

# Check for duplicate group names
$in{'name'} =~ /^[A-z0-9\-\_\.\@]+$/ && $in{'name'} !~ /^\@/ ||
	&error(&text('gsave_ename', $in{'name'}));
$in{'name'} eq 'webmin' && &error($text{'gsave_enamewebmin'});
if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
	my $clash = &get_group($in{'name'});
	$clash && &error(&text('gsave_edup', $in{'name'}));
	}
$in{'desc'} !~ /:/ || &error($text{'gsave_edesc'});

# Check grantable modules before changing parent group membership.
$access{'mode'} == 1 && !$me && &error($text{'edit_egone'});
my @mcan = $access{'mode'} == 1 ? @{$me->{'modules'} || []} :
	   $access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
				  &list_modules();
my %mcan = map { $_, 1 } @mcan;
# Keep existing modules that this administrator cannot change.
my %keep = map { $_, 1 } grep { !$mcan{$_} }
		($old ? @{$old->{'modules'}} : ());
my @mods = split(/\0/, $in{'mod'});
foreach my $m (@mods) {
	$mcan{$m} || $keep{$m} || &error(&text('save_emod', &html_escape($m)));
	}
@mods = &unique(@mods, keys %keep);

# Find the current parent group
my $oldgroup;
if ($in{'old'}) {
	foreach my $g (&list_groups()) {
		if (&indexof('@'.$in{'old'}, @{$g->{'members'}}) >= 0) {
			$oldgroup = $g;
			}
		}
	}

# Keep the current parent and its permissions when the selector is omitted.
my $newgroup = $oldgroup;
if (defined($in{'group'})) {
	# Check permission to change or remove the parent.
	if ($access{'gassign'} ne '*') {
		my @gcan = split(/\s+/, $access{'gassign'});
		$in{'group'} && &indexof($in{'group'}, @gcan) >= 0 ||
		  !$in{'group'} && &indexof('_none', @gcan) >= 0 ||
		  $oldgroup && $oldgroup->{'name'} eq $in{'group'} ||
			&error($text{'save_egroup'});
		}

	# Store parent group membership
	$newgroup = &get_group($in{'group'});
	if ($in{'group'} ne ($oldgroup ? $oldgroup->{'name'} : '')) {
		# Group has changed - update the member lists
		if ($oldgroup) {
			$oldgroup->{'members'} =
				[ grep { $_ ne '@'.$in{'old'} }
				  @{$oldgroup->{'members'}} ];
			&modify_group($oldgroup->{'name'}, $oldgroup);
			}
		if ($newgroup) {
			push(@{$newgroup->{'members'}}, '@'.$in{'name'});
			&modify_group($in{'group'}, $newgroup);
			}
		}
	}

if ($oldgroup) {
	# Remove modules from the old parent group
	@mods = grep { &indexof($_, @{$oldgroup->{'modules'}}) < 0 } @mods;
	}

if ($newgroup) {
	# Add modules from parent group to list
	my @ownmods;
	foreach my $m (@mods) {
		push(@ownmods, $m)
			if (&indexof($m, @{$newgroup->{'modules'}}) < 0);
		}
	@mods = &unique(@mods, @{$newgroup->{'modules'}});
	$group{'ownmods'} = \@ownmods;
	}

# Store group options
$group{'modules'} = \@mods;
$group{'name'} = $in{'name'};
$group{'desc'} = $in{'desc'};

if (!$in{'old'}) {
	# Database groups need an ID before inherited ACLs can be stored.
	&create_group(\%group);
	}

if ($newgroup) {
	# Use this parent even when no parent was submitted.
	# Copy inherited ACLs before a rename or any cloned permissions.
	my $name = $in{'old'} ? $in{'old'} : $in{'name'};
	&copy_group_acl_files($newgroup->{'name'}, $name,
			      [ @{$newgroup->{'modules'}}, "" ]);
	}

if ($in{'old'}) {
	# update group
	&modify_group($in{'old'}, \%group);

	# recursively update all member users and groups
	my @glist = &list_groups();
	my @ulist = &list_users();
	&update_members(\@ulist, \@glist, $group{'modules'},
			$old->{'members'});
	}
elsif ($in{'clone'}) {
	# Preserve the clone's ACLs over inherited defaults.
	&copy_group_acl_files($in{'clone'}, $group{'name'},
			      [ "", &list_modules() ]);
	}

if ($in{'old'} && $in{'acl_security_form'} && !$newgroup) {
	# Save direct global permissions only for groups without a parent.
	my $aclfile = "$config_directory/$in{'name'}.gacl";
	&lock_file($aclfile);
	&save_group_module_acl(\%global_access, $in{'name'}, "", 1);
	&set_ownership_permissions(undef, undef, 0640, $aclfile);
	&unlock_file($aclfile);
	}

if ($in{'old'} && ($in{'acl_security_form'} || $newgroup)) {
	# Apply the saved policy, including any endpoint inherited from a parent.
	# Subgroup forms must not overwrite inherited global permissions.
	my %uaccess = &get_group_module_acl($in{'name'}, '', 1);
	if ($uaccess{'api_only'}) {
		# Restrict members while retaining their saved endpoints.
		my @users = &list_users();
		my @groups = &list_groups();
		&set_acl_files(\@users, \@groups, '', $group{'members'},
			      \%uaccess);
		}
	}

&reload_miniserv();
if ($in{'old'}) {
	&webmin_log("modify", "group", $in{'old'}, \%in);
	}
else {
	&webmin_log("create", "group", $group{'name'}, \%in);
	}
&redirect("");

