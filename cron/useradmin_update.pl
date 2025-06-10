
do 'cron-lib.pl';

# useradmin_create_user(&details)
sub useradmin_create_user
{
}

# useradmin_delete_user(&details)
# Delete this user's cron file
sub useradmin_delete_user
{
&lock_file("$config{'cron_dir'}/$_[0]->{'user'}");
unlink("$config{'cron_dir'}/$_[0]->{'user'}");
&unlock_file("$config{'cron_dir'}/$_[0]->{'user'}");
}

# useradmin_modify_user(&details, &old)
sub useradmin_modify_user
{
# If a user's login name has changed, update all his Cron jobs
if ($_[0]->{'user'} ne $_[0]->{'olduser'}) {
	if (-r "$config{'cron_dir'}/$_[0]->{'olduser'}") {
		&rename_logged("$config{'cron_dir'}/$_[0]->{'olduser'}",
			       "$config{'cron_dir'}/$_[0]->{'user'}");
		}
	foreach $j (&list_cron_jobs()) {
		if ($j->{'user'} eq $_[0]->{'olduser'}) {
			&lock_file($j->{'file'});
			$j->{'user'} = $_[0]->{'user'};
			&change_cron_job($j);
			&unlock_file($j->{'file'});
			}
		}
	}

# If the user's home has changed, update all Cron job paths
if ($_[1] && $_[1]->{'home'} ne '/' && $_[0]->{'home'} ne $_[1]->{'home'}) {
	foreach $j (&list_cron_jobs()) {
		if ($j->{'user'} eq $_[0]->{'user'}) {
			if ($j->{'command'} =~
			    s/$_[1]->{'home'}/$_[0]->{'home'}/g) {
				&lock_file($j->{'file'});
				&change_cron_job($j);
				&unlock_file($j->{'file'});
				}
			}
		}
	}
}

1;

