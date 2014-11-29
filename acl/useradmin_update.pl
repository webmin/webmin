
use strict;
use warnings;
if (!$main::done_foreign_require{"acl","acl-lib.pl"}) {
	do "acl-lib.pl";
	}
our (%config, $config_directory);

# useradmin_create_user(&details)
# Create a new webmin user in the group
sub useradmin_create_user
{
return if (!$config{'sync_create'});
my $group = &get_group($config{'sync_group'});
return if (!$group);
my $clash = &get_user($_[0]->{'user'}) || &get_group($_[0]->{'user'});
return if ($clash);
return if ($_[0]->{'user'} !~ /^[A-z0-9\-\_\.]+$/);
my $user = { 'name' => $_[0]->{'user'},
	     'pass' => $config{'sync_unix'} ? 'x' : $_[0]->{'pass'},
	     'sync' => 1,
	     'modules' => $group->{'modules'} };
&create_user($user);
push(@{$group->{'members'}}, $user->{'name'});
&modify_group($group->{'name'}, $group);

foreach my $m (@{$group->{'modules'}}, "") {
	my %groupacl;
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
my $u = &get_user($_[0]->{'user'});
if ($u) {
	&delete_user($u->{'name'});
	&reload_miniserv();
	}
foreach my $g (&list_groups()) {
	next if (!$g->{'members'});
	my @mems = @{$g->{'members'}};
	my $i = &indexof($_[0]->{'user'}, @mems);
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
my $u = &get_user($_[0]->{'olduser'});
if ($u && $u->{'sync'}) {
	if ($_[0]->{'user'} ne $_[0]->{'olduser'}) {
		# New name might clash (or be invalid)
		my $clash = &get_user($_[0]->{'user'}) ||
			       &get_group($_[0]->{'user'});
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


if ($_[0]->{'olduser'} && $_[0]->{'user'} ne $_[0]->{'olduser'}) {
	# Check other users' acl module acls
	foreach my $u (&list_users()) {
		my %uaccess = &get_module_acl($u->{'name'});
		my @au = split(/\s+/, $uaccess{'users'});
		my $idx = &indexof($_[0]->{'olduser'}, @au);
		if ($idx != -1) {
			$au[$idx] = $_[0]->{'user'};
			$uaccess{'users'} = join(" ", @au);
			&save_module_acl(\%uaccess, $u->{'name'});
			}
		}

	# Rename the user in his group
	foreach my $g (&list_groups()) {
		my @mems = @{$g->{'members'}};
		my $i = &indexof($_[0]->{'olduser'}, @mems);
		if ($i >= 0) {
			$mems[$i] = $_[0]->{'user'};
			$g->{'members'} = \@mems;
			&modify_group($g->{'name'}, $g);
			}
		}
	}
}

1;

