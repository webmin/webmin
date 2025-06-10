
do 'sshd-lib.pl';

# useradmin_create_user(&details)
# Setup SSH and GNUPG for new users
sub useradmin_create_user
{
my ($uinfo) = @_;
if ($config{'sync_create'} && &has_command($config{'keygen_path'}) &&
    -d $uinfo->{'home'} && !-d "$uinfo->{'home'}/.ssh") {
	local $cmd;
	local $type = $config{'sync_type'} || &get_preferred_key_type();
	local $tflag = $type ? "-t $type" : "";
	if ($config{'sync_pass'} && $uinfo->{'passmode'} == 3) {
		$cmd = "$config{'keygen_path'} $tflag -P ".
		       quotemeta($uinfo->{'plainpass'});
		}
	else {
		$cmd = "$config{'keygen_path'} $tflag -P \"\"";
		}
	&system_logged("echo '' | ".&command_as_user($uinfo->{'user'}, 0, $cmd).
		       " >/dev/null 2>&1");
	if ($config{'sync_auth'}) {
		my $akeys = "$uinfo->{'home'}/.ssh/authorized_keys";
		&lock_file($akeys);
		if (-r "$uinfo->{'home'}/.ssh/identity.pub") {
			&copy_source_dest("$uinfo->{'home'}/.ssh/identity.pub", $akeys);
			}
		elsif (-r "$uinfo->{'home'}/.ssh/id_rsa.pub") {
			&copy_source_dest("$uinfo->{'home'}/.ssh/id_rsa.pub", $akeys);
			}
		else {
			&copy_source_dest("$uinfo->{'home'}/.ssh/id_dsa.pub", $akeys);
			}
		&set_ownership_permissions($uinfo->{'uid'}, $uinfo->{'gid'}, undef, $akeys);
		&unlock_file($akeys);
		}
	}
}

# useradmin_delete_user(&details)
sub useradmin_delete_user
{
}

# useradmin_modify_user(&details)
sub useradmin_modify_user
{
}

1;

