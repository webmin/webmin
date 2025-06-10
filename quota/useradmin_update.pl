
do 'quota-lib.pl';

# useradmin_create_user(&details)
# Sets quotas on chosen filesystems
sub useradmin_create_user
{
local ($anysync) = grep { /^sync_/ } (keys %config);
return if (!$anysync);
local ($k, $fs, $i, %fslist);
foreach $fs (&list_filesystems()) {
	if ($fs->[4] && $fs->[5]) {
		$fslist{$fs->[0]}++;
		}
	}
foreach $k (keys %config) {
	if ($k =~ /^sync_(\S+)$/ && $fslist{$1}) {
		# found a filesystem to set quotas on
		$fs = $1;
		@quot = split(/\s+/, $config{$k});
		&edit_user_quota($_[0]->{'user'}, $fs, @quot);
		}
	}
}

# useradmin_delete_user(&details)
# Zero the quotas of a deleted user
sub useradmin_delete_user
{
foreach $fs (&list_filesystems()) {
	if ($fs->[4] && $fs->[5]) {
		$fslist{$fs->[0]}++;
		}
	}
$n = &user_filesystems($_[0]->{'user'});
for($i=0; $i<$n; $i++) {
	$f = $filesys{$i,'filesys'};
	if ($fslist{$f}) {
		# user has quota, and filesystem is local
		&edit_user_quota($_[0]->{'user'}, $f, 0, 0, 0, 0);
		}
	}
}

# useradmin_modify_user(&details)
# Quotas are stored by UID, so no need to change anything
# when a username changes.
sub useradmin_modify_user
{
# XXX should change if UID changes?
}


# useradmin_create_group(&details)
# Sets quotas on chosen filesystems
sub useradmin_create_group
{
local ($anysync) = grep { /^gsync_/ } (keys %config);
return if (!$anysync);
return if (!defined(&edit_group_quota) || !defined(&group_filesystems));
local ($k, $fs, $i, %fslist);
foreach $fs (&list_filesystems()) {
	if ($fs->[4] && $fs->[5]) {
		$fslist{$fs->[0]}++;
		}
	}
foreach $k (keys %config) {
	if ($k =~ /^gsync_(\S+)$/ && $fslist{$1}) {
		# found a filesystem to set quotas on
		$fs = $1;
		@quot = split(/\s+/, $config{$k});
		&edit_group_quota($_[0]->{'group'}, $fs, @quot);
		}
	}
}

# useradmin_delete_group(&details)
# Zero the quotas of a deleted group
sub useradmin_delete_group
{
return if (!defined(&edit_group_quota) || !defined(&group_filesystems));
foreach $fs (&list_filesystems()) {
	if ($fs->[4] && $fs->[5]) {
		$fslist{$fs->[0]}++;
		}
	}
$n = &group_filesystems($_[0]->{'group'});
for($i=0; $i<$n; $i++) {
	$f = $filesys{$i,'filesys'};
	if ($fslist{$f}) {
		# group has quota, and filesystem is local
		&edit_group_quota($_[0]->{'group'}, $f, 0, 0, 0, 0);
		}
	}
}

# useradmin_modify_group(&details)
# Quotas are stored by UID, so no need to change anything
# when a group name changes.
sub useradmin_modify_group
{
return if (!defined(&edit_group_quota) || !defined(&group_filesystems));
# XXX should change if UID changes?
}


1;

