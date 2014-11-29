
if (!$main::done_foreign_require{"htaccess_htpasswd","htaccess-lib.pl"}) {
	require 'htaccess-lib.pl';
	}

sub useradmin_create_user
{
foreach $dir (&list_directories()) {
	next if ($dir->[3] !~ /create/);
	local $users = &list_users($dir->[1]);
	local ($clash) = grep { $_->{'user'} eq $_[0]->{'user'} } @$users;
	return if ($clash);
	&lock_file($dir->[1]);
	local $user = { 'user' => $_[0]->{'user'},
			'enabled' => 1 };
	if ($_[0]->{'passmode'} == 0) {
		$user->{'pass'} = "";
		}
	elsif ($_[0]->{'passmode'} == 1) {
		$user->{'pass'} = "*LK*";
		}
	elsif ($_[0]->{'passmode'} == 2) {
		$user->{'pass'} = $_[0]->{'pass'};
		}
	else {
		$user->{'pass'} = &encrypt_password($_[0]->{'plainpass'},
						    undef, $config{'md5'});
		}
	&create_user($user, $dir->[1]);
	&unlock_file($dir->[1]);
	}
}

sub useradmin_modify_user
{
foreach $dir (&list_directories()) {
	next if ($dir->[3] !~ /update/);
	local $users = &list_users($dir->[1]);
	local ($user) = grep { $_->{'user'} eq $_[0]->{'olduser'} } @$users;
	return if (!$user);
	&lock_file($dir->[1]);
	$user->{'user'} = $_[0]->{'user'};
	if ($_[0]->{'passmode'} == 0) {
		$user->{'pass'} = "";
		}
	elsif ($_[0]->{'passmode'} == 1) {
		$user->{'pass'} = "*LK*";
		}
	elsif ($_[0]->{'passmode'} == 2) {
		$user->{'pass'} = $_[0]->{'pass'};
		}
	elsif ($_[0]->{'passmode'} == 3) {
		$user->{'pass'} = &encrypt_password($_[0]->{'plainpass'},
						    undef, $config{'md5'});
		}
	&modify_user($user);
	&unlock_file($dir->[1]);
	}
}

sub useradmin_delete_user
{
foreach $dir (&list_directories()) {
	next if ($dir->[3] !~ /update/);
	local $users = &list_users($dir->[1]);
	local ($user) = grep { $_->{'user'} eq $_[0]->{'user'} } @$users;
	return if (!$user);
	&lock_file($dir->[1]);
	&delete_user($user);
	&unlock_file($dir->[1]);
	}
}

1;
