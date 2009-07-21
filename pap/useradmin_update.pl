
do 'pap-lib.pl';

# useradmin_create_user(&details)
# Add a PAP user if syncing is enabled
sub useradmin_create_user
{
return if (!$config{'sync_add'});
@sec = &list_secrets();
foreach $s (@sec) {
	return if ($s->{'client'} eq $_[0]->{'user'});
	}
$sec{'client'} = $_[0]->{'user'};
$sec{'server'} = $config{'sync_server'} ? $config{'sync_server'} : "*";
&compute_password($_[0], \%sec);
$sec{'ips'} = [ ];
&create_secret(\%sec);
}

# useradmin_delete_user(&details)
# Delete this pap user if syncing
sub useradmin_delete_user
{
return if (!$config{'sync_delete'});
@sec = &list_secrets();
for($i=0; $i<@sec; $i++) {
	if ($sec[$i]->{'client'} eq $_[0]->{'user'}) {
		&delete_secret($sec[$i]);
		return;
		}
	}
}

# useradmin_modify_user(&details)
# Update this user if in sync
sub useradmin_modify_user
{
return if (!$config{'sync_change'});
@sec = &list_secrets();
for($i=0; $i<@sec; $i++) {
	if ($sec[$i]->{'client'} eq $_[0]->{'olduser'}) {
		$sec[$i]->{'client'} = $_[0]->{'user'};
		&compute_password($_[0], $sec[$i]);
		&change_secret($sec[$i]);
		return;
		}
	}
}

# compute_password(&user, &secret)
sub compute_password
{
if ($_[0]->{'passmode'} == 0) {
	$_[1]->{'secret'} = &opt_crypt("");
	}
elsif ($_[0]->{'passmode'} == 1) {
	$_[1]->{'secret'} = "*LK*";
	}
elsif ($_[0]->{'passmode'} == 2) {
	$_[1]->{'secret'} = $_[0]->{'pass'} if ($config{'encrypt_pass'});
	}
elsif ($_[0]->{'passmode'} == 3) {
	$_[1]->{'secret'} = &opt_crypt($_[0]->{'plainpass'});
	}
}

1;

