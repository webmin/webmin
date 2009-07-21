
do 'bind8-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;

# Add main .conf files
local $conf = &get_config();
push(@rv, map { $_->{'file'} } @$conf);

# Add all master zone files
local @views = &find("view", $conf);
local ($v, @zones);
foreach $v (@views) {
	local @vz = &find("zone", $v->{'members'});
	push(@zones, @vz);
	}
push(@zones, &find("zone", $conf));
local $z;
foreach $z (@zones) {
	local $tv = &find_value("type", $z->{'members'});
	next if ($tv ne "master");
	local $file = &find_value("file", $z->{'members'});
	next if (!$file);
	local @recs = &read_zone_file($file, $z->{'value'});
	push(@rv, map { $_->{'file'} } @recs);
	}

return map { &make_chroot($_) } &unique(@rv);
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
local $pidfile = &get_pid_file();
if (&check_pid_file(&make_chroot($pidfile, 1))) {
	return &restart_bind();
	}
return undef;
}

1;

