
do "acl-lib.pl";

# useradmin_create_user(&details)
# Create a new webmin user in the group
sub useradmin_create_user
{
return if (!$config{'sync_create'});
local ($group) = grep { $_->{'name'} eq $config{'sync_group'} }
		      &list_groups();
return if (!$group);
local ($clash) = grep { $_->{'name'} eq $_[0]->{'user'} }
			(&list_users(), &list_groups());
return if ($clash);
return if ($_[0]->{'user'} !~ /^[A-z0-9\-\_\.]+$/);
local $user = { 'name' => $_[0]->{'user'},
		'pass' => $config{'sync_unix'} ? 'x' : $_[0]->{'pass'},
		'sync' => 1,
		'modules' => $group->{'modules'} };
&create_user($user);
push(@{$group->{'members'}}, $user->{'name'});
&modify_group($group->{'name'}, $group);

foreach $m (@{$group->{'modules'}}, "") {
	local %groupacl;
	unlink("$config_directory/$m/$user->{'name'}.acl");
	if (&read_file("$config_directory/$m/$group->{'name'}.gacl",
		       \%groupacl)) {
		&write_file("$config_directory/$m/$user->{'name'}.acl",
			    \%groupacl);
		}
	}
&reload_miniserv();
}

# useradmin_delete_user(&details)
# Delete this webmin user if in sync
sub useradmin_delete_user
{
return if (!$config{'sync_delete'});
local @list = &list_users();
foreach $u (@list) {
	if ($u->{'name'} eq $_[0]->{'user'}) {
		&delete_user($u->{'name'});
		&reload_miniserv();
		}
	}
foreach $g (&list_groups()) {
	local @mems = @{$g->{'members'}};
	local $i = &indexof($_[0]->{'user'}, @mems);
	if ($i >= 0) {
		splice(@mems, $i, 1);
		$g->{'members'} = \@mems;
		&modify_group($g->{'name'}, $g);
		}
	}
}

# useradmin_modify_user(&details)
# Update this users password if in sync
sub useradmin_modify_user
{
return if ($_[0]->{'passmode'} == 4 && $_[0]->{'olduser'} eq $_[0]->{'user'});
foreach $u (&list_users()) {
	if ($u->{'name'} eq $_[0]->{'olduser'} && $u->{'sync'}) {
		if ($_[0]->{'user'} ne $_[0]->{'olduser'}) {
			# New name might clash (or be invalid)
			local ($clash) =grep { $_->{'name'} eq $_[0]->{'user'} }
						(&list_users(), &list_groups());
			return if ($clash);
			return if ($_[0]->{'user'} !~ /^[A-z0-9\-\_\.]+$/);
			}
		$u->{'name'} = $_[0]->{'user'};
		if ($u->{'pass'} ne 'x') {
			$u->{'pass'} = $_[0]->{'passmode'} == 3 ?
			   &encrypt_password($_[0]->{'plainpass'}) :
			   $_[0]->{'pass'};
			}
		&modify_user($_[0]->{'olduser'}, $u);
		&reload_miniserv();
		}

	# Check other users' acl module acls
	local %uaccess = &get_module_acl($u->{'name'});
	local @au = split(/\s+/, $uaccess{'users'});
	local $idx = &indexof($_[0]->{'olduser'}, @au);
	if ($idx != -1) {
		$au[$idx] = $_[0]->{'user'};
		$uaccess{'users'} = join(" ", @au);
		&save_module_acl(\%uaccess, $u->{'name'});
		}
	}

# Rename the user in his group
if ($_[0]->{'user'} ne $_[0]->{'olduser'}) {
	foreach $g (&list_groups()) {
		local @mems = @{$g->{'members'}};
		local $i = &indexof($_[0]->{'olduser'}, @mems);
		if ($i >= 0) {
			$mems[$i] = $_[0]->{'user'};
			$g->{'members'} = \@mems;
			&modify_group($g->{'name'}, $g);
			}
		}
	}
}

1;

