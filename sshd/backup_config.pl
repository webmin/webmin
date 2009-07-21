
do 'sshd-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv = ( $config{'sshd_config'}, $config{'client_config'} );
if ($config{'sshd_config'} =~ /^(.*)\//) {
	local $sshd_dir = $1;
	opendir(DIR, $sshd_dir);
	local $f;
	foreach $f (readdir(DIR)) {
		next if ($f eq "." || $f eq ".." || $f =~ /\.rpmsave$/i);
		push(@rv, "$sshd_dir/$f");
		}
	closedir(DIR);
	}
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
return &restart_sshd();
}

1;

