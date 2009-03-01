
do 'htpasswd-file-lib.pl';

sub useradmin_create_user
{
return if (!$config{'file'});
local $users = &list_users();
local ($clash) = grep { $_->{'user'} eq $_[0]->{'user'} } @$users;
return if ($clash);
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
&create_user($user);
}

sub useradmin_modify_user
{
return if (!$config{'file'});
local $users = &list_users();
local ($user) = grep { $_->{'user'} eq $_[0]->{'olduser'} } @$users;
return if (!$user);
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
}

sub useradmin_delete_user
{
return if (!$config{'file'});
local $users = &list_users();
local ($user) = grep { $_->{'user'} eq $_[0]->{'user'} } @$users;
return if (!$user);
&delete_user($user);
}

