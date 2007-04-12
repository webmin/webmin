
do 'bandwidth-lib.pl';
&foreign_require("firewall", "backup_config.pl");
&foreign_require($syslog_module, "backup_config.pl");

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
# Just backup syslog and firewall
return ( &firewall::backup_config_files(),
	 &foreign_call($syslog_module, "backup_config_files") );
}

# pre_backup(&files)
# Called before the files are actually read
sub pre_backup
{
return &firewall::pre_backup() &&
       &foreign_call($syslog_module, "pre_backup");
}

# post_backup(&files)
# Called after the files are actually read
sub post_backup
{
return &firewall::post_backup() &&
       &foreign_call($syslog_module, "post_backup");
}

# pre_restore(&files)
# Called before the files are restored from a backup
sub pre_restore
{
return &firewall::pre_restore() &&
       &foreign_call($syslog_module, "pre_restore");
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
return &firewall::post_restore() &&
       &foreign_call($syslog_module, "post_restore");
}

1;

