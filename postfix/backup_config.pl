
do 'postfix-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv;

# Add main config file
push(@rv, $config{'postfix_config_file'});

# Add known map files
push(@rv, &get_maps_files("alias_maps"));
push(@rv, &get_maps_files("alias_database"));
push(@rv, &get_maps_files("canonical_maps"));
push(@rv, &get_maps_files("recipient_canonical_maps"));
push(@rv, &get_maps_files("sender_canonical_maps"));
push(@rv, &get_maps_files($virtual_maps));
push(@rv, &get_maps_files("transport_maps"));
push(@rv, &get_maps_files("relocated_maps"));

# Add other files in /etc/postfix
local $cdir = &guess_config_dir();
opendir(DIR, $cdir);
foreach $f (readdir(DIR)) {
	next if ($f eq "." || $f eq ".." || $f =~ /\.(db|dir|pag)$/i);
	push(@rv, "$cdir/$f");
	}
closedir(DIR);

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
if (&is_postfix_running()) {
	local $out = `$config{'postfix_control_command'} -c $config_dir reload 2>&1`;
	return "<tt>$out</tt>" if ($?);
	}
return undef;
}

1;

