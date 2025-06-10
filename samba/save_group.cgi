#!/usr/local/bin/perl
# save_group.cgi
# Update or delete a Samba group

require './samba-lib.pl';

$access{'maint_groups'} || &error($text{'groups_ecannot'});
&ReadParse();
@groups = &list_groups();
$group = $groups[$in{'idx'}] if (!$in{'new'});
$oldname = $group->{'name'} || $in{'name'};

if ($in{'delete'}) {
	# Just remove this group
	&delete_group($group);
	}
else {
	# Validate inputs
	&error_setup($text{'gsave_err'});
	if ($in{'new'}) {
		$in{'name'} =~ /\S/ || &error($text{'gsave_ename'});
		$group->{'name'} = $in{'name'};
		}
	$group->{'type'} = $in{'type'};
	if ($in{'unix_def'}) {
		$group->{'unix'} = -1;
		}
	else {
		getgrnam($in{'unix'}) || $in{'unix'} =~ /^\-?\d+$/ ||
			&error($text{'gsave_eunix'});
		$group->{'unix'} = $in{'unix'};
		}
	$group->{'desc'} = $in{'desc'};
	if ($in{'new'} && !$in{'priv_def'}) {
		$in{'priv'} =~ /\S/ || &error($text{'gsave_epriv'});
		$in{'type'} eq 'l' || &error($text{'gsave_elocal'});
		$group->{'priv'} = $in{'priv'};
		}

	# Update or create the group
	if ($in{'new'}) {
		&create_group($group);
		}
	else {
		&modify_group($group);
		}
	}
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "group", $oldname, \%group);
&redirect("list_groups.cgi");

