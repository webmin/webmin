
do 'samba-lib.pl';

# useradmin_create_user(&details)
# Create a new samba user if sync is enabled
sub useradmin_create_user
{
&get_share("global");
if (&istrue("encrypt passwords") && ($config{'smb_passwd'} || $has_pdbedit) &&
    $config{'sync_add'} && !&get_user($_[0]->{'user'})) {
	# Add a user to smbpasswd
	&lock_file($config{'smb_passwd'});
	local $u = { 'name' => $_[0]->{'user'},
		     'uid' => $_[0]->{'uid'} };
	if ($samba_version >= 2) {
		local @opts = ("U");
		push(@opts, "N") if ($_[0]->{'passmode'} == 0);
		push(@opts, "D") if ($_[0]->{'passmode'} == 1);
		$u->{'opts'} = \@opts;
		}
	else {
		$u->{'real'} = $_[0]->{'real'};
		$u->{'home'} = $_[0]->{'home'};
		$u->{'shell'} = $_[0]->{'shell'};
		}
	$u->{'pass1'} = $u->{'pass2'} = ("X" x 32);
	if ($_[0]->{'passmode'} == 0) {
		$u->{'pass1'} = "NO PASSWORDXXXXXXXXXXXXXXXXXXXXX";
		$u->{'pass2'} = $u->{'pass1'};
		}
	&create_user($u);
	if ($_[0]->{'passmode'} == 3) {
		&set_password($_[0]->{'user'}, $_[0]->{'plainpass'});
		}
	&unlock_file($config{'smb_passwd'});
	}
}

# useradmin_delete_user(&details)
# Delete a samba user
sub useradmin_delete_user
{
&get_share("global");
if (&istrue("encrypt passwords") && ($config{'smb_passwd'} || $has_pdbedit) &&
    $config{'sync_delete'} && ($u = &get_user($_[0]->{'user'}))) {
	# Delete the user
	&lock_file($config{'smb_passwd'});
	&delete_user($u);
	&unlock_file($config{'smb_passwd'});
	}

if ($config{'sync_delete_profile'}) {
	# Delete his roaming profile, if any
	if (&get_share("Profiles")) {
		local $ppath = &getval("path");
		if ($ppath) {
			foreach my $upath ("$ppath/$_[0]->{'user'}",
					   "$ppath/$_[0]->{'user'}.v2") {
				if (-d $upath) {
					&system_logged("rm -rf ".quotemeta($upath));
					}
				elsif (-r $upath) {
					&lock_file($upath);
					unlink($upath);
					&unlock_file($upath);
					}
				}
			}
		}
	}

}

# useradmin_modify_user(&details)
# Update a samba user
sub useradmin_modify_user
{
&get_share("global");
if (&istrue("encrypt passwords") && ($config{'smb_passwd'} || $has_pdbedit) &&
    $config{'sync_change'} && ($u = &get_user($_[0]->{'olduser'}))) {
	# Update details
	&lock_file($config{'smb_passwd'});
	$u->{'uid'} = $_[0]->{'uid'};
	$u->{'name'} = $_[0]->{'user'};
	if ($u->{'opts'}) {
		local @opts = grep { !/[ND]/ } @{$u->{'opts'}};
		push(@opts, "N") if ($_[0]->{'passmode'} == 0);
		push(@opts, "D") if ($_[0]->{'passmode'} == 1);
		$u->{'opts'} = \@opts;
		}
	else {
		$u->{'real'} = $_[0]->{'real'};
		$u->{'home'} = $_[0]->{'home'};
		$u->{'shell'} = $_[0]->{'shell'};
		}
	if ($_[0]->{'passmode'} == 0) {
		$u->{'pass1'} = "NO PASSWORDXXXXXXXXXXXXXXXXXXXXX";
		$u->{'pass2'} = $u->{'pass1'};
		}
	elsif ($_[0]->{'passmode'} == 1) {
		$u->{'pass1'} = $u->{'pass2'} = ("X" x 32);
		}
	&modify_user($u);
	if ($_[0]->{'passmode'} == 3) {
		&set_password($_[0]->{'user'}, $_[0]->{'plainpass'});
		}
	&unlock_file($config{'smb_passwd'});
	}

if ($config{'sync_change_profile'}) {
	# Rename his roaming profile, if any
	if (&get_share("Profiles")) {
		local $ppath = &getval("path");
		if ($ppath) {
			local $upath = "$ppath/$_[0]->{'olduser'}";
			local $newupath = "$ppath/$_[0]->{'user'}";
			if (-e $upath) {
				&rename_logged($upath, $newupath);
				}
			}
		}
	}

}

sub get_user
{
local @ulist = &list_users();
local $u;
foreach $u (@ulist) {
	return $u if ($u->{'name'} eq $_[0]);
	}
return undef;
}


# When running Samba 3.x, these functions update the Samba groups file to
# match Unix groups

# useradmin_create_group(&group)
sub useradmin_create_group
{
return if (!$config{'gsync_add'});
return if ($samba_version < 3 || 
	   (!$has_smbgroupedit && !$has_net));
local $clash = &get_group($_[0]->{'group'});
return if ($clash);

local $group = { 'name' => $_[0]->{'group'},
		 'unix' => $_[0]->{'group'},
		 'type' => $config{'gsync_type'} };
if ($group->{'type'} eq 'l') {
	$group->{'priv'} = $config{'gsync_priv'};
	}
&create_group($group);
}

# useradmin_delete_group(&group)
sub useradmin_delete_group
{
return if (!$config{'gsync_delete'});
return if ($samba_version < 3 || 
	   (!$has_smbgroupedit && !$has_net));
local $group = &get_group($_[0]->{'group'});
return if (!$group);

&delete_group($group);
}

# useradmin_modify_group(&group, &oldgroup)
sub useradmin_modify_group
{
return if (!$config{'gsync_change'});
return if ($_[0]->{'group'} eq $_[1]->{'group'});
return if ($samba_version < 3 || 
	   (!$has_smbgroupedit && !$has_net));
local $group = &get_group($_[1]->{'group'});
return if (!$group);

$group->{'name'} = $_[0]->{'group'};
&modify_group($group);
# XXX clash?
}

sub get_group
{
local @glist = &list_groups();
local $g;
foreach $g (@glist) {
	return $g if ($g->{'name'} eq $_[0]);
	}
return undef;
}

1;

