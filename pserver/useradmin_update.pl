
do 'pserver-lib.pl';

# useradmin_create_user(&details)
# Create a new CVS user if syncing is enabled
sub useradmin_create_user
{
if ($config{'sync_create'}) {
	local $salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
	local $user = { 'user' => $_[0]->{'user'},
			'pass' => $_[0]->{'passmode'} == 3 ?
			    &unix_crypt($_[0]->{'plainpass'}, $salt) : $_[0]->{'pass'},
			'unix' => $config{'sync_user'} };
	&create_password($user);
	}
}

# useradmin_delete_user(&details)
# Delete a mysql user
sub useradmin_delete_user
{
if ($config{'sync_delete'}) {
	local @passwd = &list_passwords();
	local ($user) = grep { $_->{'user'} eq $_[0]->{'user'} } @passwd;
	&delete_password($user) if ($user);
	}
}

# useradmin_modify_user(&details)
# Update a mysql user
sub useradmin_modify_user
{
if ($config{'sync_modify'}) {
	local @passwd = &list_passwords();
	local ($user) = grep { $_->{'user'} eq $_[0]->{'olduser'} } @passwd;
	if ($user) {
		local $salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
		$user->{'user'} = $_[0]->{'user'};
		if ($_[0]->{'passmode'} == 3) {
			$user->{'pass'} = &unix_crypt($_[0]->{'plainpass'}, $salt);
			}
		elsif ($_[0]->{'passmode'} != 4) {
			$user->{'pass'} = $_[0]->{'pass'};
			}
		&modify_password($user);
		}
	}
}

1;

