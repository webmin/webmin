
do 'cron-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;
push(@rv, map { $_->{'file'} } &list_cron_jobs());
push(@rv, $config{'cron_allow_file'}) if ($config{'cron_allow_file'});
push(@rv, $config{'cron_deny_file'}) if ($config{'cron_deny_file'});
push(@rv, $config{'system_crontab'}) if ($config{'system_crontab'});
return &unique(@rv);
}

# pre_backup(&files)
# Called before the files are actually read
sub pre_backup
{
return undef;
}

# post_backup(&files)
# Called after the files are actually read
sub post_backup
{
return undef;
}

# pre_restore(&files)
# Called before the files are restored from a backup
sub pre_restore
{
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
if (!$fcron) {
	# Re-activate all user cron jobs
	local $user;
	opendir(DIR, $config{'cron_dir'});
	while($user = readdir(DIR)) {
		system("cp $config{'cron_dir'}/$user $cron_temp_file");
		&copy_crontab($user);
		}
	closedir(DIR);
	}
return undef;
}

1;

