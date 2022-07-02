
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
if (!$main::done_foreign_require{"acl","acl-lib.pl"}) {
	do "acl-lib.pl";
	}
our (%config, $config_directory);

# useradmin_create_user(&details)
# Create a new webmin user in the group
sub useradmin_create_user
{
my ($unix) = @_;
return if (!$config{'sync_create'});
my $group = &get_group($config{'sync_group'});
return if (!$group);
my $clash = &get_user($unix->{'user'}) || &get_group($unix->{'user'});
return if ($clash);
return if ($unix->{'user'} !~ /^[A-z0-9\-\_\.]+$/);
my $user = { 'name' => $unix->{'user'},
	     'pass' => $config{'sync_unix'} ? 'x' : $unix->{'pass'},
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
my ($unix) = @_;
return if (!$config{'sync_delete'});
my $u = &get_user($unix->{'user'});
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
my ($unix) = @_;
return if ($unix->{'passmode'} == 4 && $unix->{'olduser'} eq $unix->{'user'});
my $u = &get_user($unix->{'olduser'});
if ($u && ($u->{'sync'} || $config{'sync_modify'})) {
	if ($unix->{'user'} ne $unix->{'olduser'}) {
		# User has been renamed .. but name might clash or be invalid
		my $clash = &get_user($unix->{'user'}) ||
			       &get_group($unix->{'user'});
		return if ($clash);
		return if ($unix->{'user'} !~ /^[A-z0-9\-\_\.]+$/);
		}
	$u->{'name'} = $unix->{'user'};
	if ($u->{'pass'} ne 'x' && $u->{'sync'}) {
		# Password has been updated
		$u->{'pass'} = $unix->{'passmode'} == 3 ?
		   &encrypt_password($unix->{'plainpass'}) :
		   $unix->{'pass'};
		}
	&modify_user($unix->{'olduser'}, $u);
	&reload_miniserv();
	}

if ($unix->{'olduser'} && $unix->{'user'} ne $unix->{'olduser'}) {
	# Check other users' acl module acls
	foreach my $u (&list_users()) {
		my %uaccess = &get_module_acl($u->{'name'});
		my @au = split(/\s+/, $uaccess{'users'});
		my $idx = &indexof($unix->{'olduser'}, @au);
		if ($idx != -1) {
			$au[$idx] = $unix->{'user'};
			$uaccess{'users'} = join(" ", @au);
			&save_module_acl(\%uaccess, $u->{'name'});
			}
		}

	# Rename the user in his group
	foreach my $g (&list_groups()) {
		my @mems = @{$g->{'members'}};
		my $i = &indexof($unix->{'olduser'}, @mems);
		if ($i >= 0) {
			$mems[$i] = $unix->{'user'};
			$g->{'members'} = \@mems;
			&modify_group($g->{'name'}, $g);
			}
		}
	}
}

1;

