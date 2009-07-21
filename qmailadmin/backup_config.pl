
do 'qmail-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local (@rv, $d, $f);
foreach $d ($qmail_control_dir, $qmail_alias_dir, $qmail_users_dir) {
	opendir(DIR, $d);
	foreach $f (readdir(DIR)) {
		next if ($f eq "." || $f eq ".." || $f =~ /\.rpmsave$/i);
		push(@rv, "$d/$f");
		}
	closedir(DIR);
	}
return @rv;
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
&restart_qmail();
return undef;
}

1;

