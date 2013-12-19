#!/usr/local/bin/perl
# save_group.cgi
# Create, modify or delete a webmin group

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $config_directory);
&ReadParse();

# Check for special button clicks, and redirect
if ($in{'but_clone'}) {
	&redirect("edit_group.cgi?clone=".&urlize($in{'old'}));
	exit;
	}
elsif ($in{'but_delete'}) {
	&redirect("delete_group.cgi?group=".&urlize($in{'old'}));
	exit;
	}

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

# Check for duplicate group names
$in{'name'} =~ /^[A-z0-9\-\_\.\@]+$/ && $in{'name'} !~ /^\@/ ||
	&error(&text('gsave_ename', $in{'name'}));
$in{'name'} eq 'webmin' && &error($text{'gsave_enamewebmin'});
if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
	my $clash = &get_group($in{'name'});
	$clash && &error(&text('gsave_edup', $in{'name'}));
	}
$in{'desc'} !~ /:/ || &error($text{'gsave_edesc'});

# Find the current parent group
my $oldgroup;
if ($in{'old'}) {
	foreach my $g (&list_groups()) {
		if (&indexof('@'.$in{'old'}, @{$g->{'members'}}) >= 0) {
			$oldgroup = $g;
			}
		}
	}

my $newgroup;
if (defined($in{'group'})) {
	# Check if group is allowed
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

# Work out group modules
my @mods = split(/\0/, $in{'mod'});

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

	# Copy ACL files for parent group
	my $name = $in{'old'} ? $in{'old'} : $in{'name'};
	&copy_group_acl_files($in{'group'}, $name,
			      [ @{$newgroup->{'modules'}}, "" ]);
	}

# Store group options
$group{'modules'} = \@mods;
$group{'name'} = $in{'name'};
$group{'desc'} = $in{'desc'};

if ($in{'old'}) {
	# update group
	&modify_group($in{'old'}, \%group);

	# recursively update all member users and groups
	my @glist = &list_groups();
	my @ulist = &list_users();
	&update_members(\@ulist, \@glist, $group{'modules'},
			$old->{'members'});
	}
else {
	# create group
	&create_group(\%group, $in{'clone'});
	}

if ($in{'old'} && $in{'acl_security_form'}) {
	# Update group's global ACL
	&foreign_require("", "acl_security.pl");
	my %uaccess;
	&foreign_call("", "acl_security_save", \%uaccess, \%in);
	my $aclfile = "$config_directory/$in{'name'}.gacl";
	&lock_file($aclfile);
	&save_group_module_acl(\%uaccess, $in{'name'}, "", 1);
	&set_ownership_permissions(undef, undef, 0640, $aclfile);
	&unlock_file($aclfile);
	}

&reload_miniserv();
if ($in{'old'}) {
	&webmin_log("modify", "group", $in{'old'}, \%in);
	}
else {
	&webmin_log("create", "group", $group{'name'}, \%in);
	}
&redirect("");

