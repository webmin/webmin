#!/usr/local/bin/perl
# Create, update or delete a group

require './htaccess-lib.pl';
&ReadParse();
&error_setup($text{'gsave_err'});
@dirs = &list_directories();
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
&lock_file($dir->[1]);

&switch_user();
$groups = &list_groups($dir->[4]);
if (!$in{'new'}) {
	$group = $groups->[$in{'idx'}];
	$loggroup = $group->{'group'};
	}
else {
	$loggroup = $in{'group'};
	}

if ($in{'delete'}) {
	# Just delete this group
	&delete_group($group);
	}
else {
	# Validate inputs
	$in{'group'} || &error($text{'gsave_egroup1'});
	$in{'group'} =~ /:/ && &error($text{'gsave_egroup2'});
	$in{'group'} =~ /^\S+$/ || &error($text{'gsave_egroup2'});
	if ($in{'new'} || $group->{'group'} ne $in{'group'}) {
		($clash) = grep { $_->{'group'} eq $in{'group'} } @$groups;
		$clash && &error($text{'gsave_eclash'});
		}

	# Actually save
	$group->{'group'} = $in{'group'};
	$group->{'enabled'} = $in{'enabled'};
	$group->{'members'} = [ split(/\s+/, $in{'members'}) ];
	if ($in{'new'}) {
		&create_group($group, $dir->[4]);
		}
	else {
		&modify_group($group);
		}
	}
&switch_back();

&unlock_file($dir->[1]);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "group", $loggroup, $group);
&redirect("");

