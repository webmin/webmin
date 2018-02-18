
use strict;
use warnings;
do 'acl-lib.pl';
our ($config_directory, %gconfig);

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
my @rv;

# Add primary user and group files
my %miniserv;
&get_miniserv_config(\%miniserv);
push(@rv, $miniserv{'userfile'});
push(@rv, &acl_filename());

# Add all .acl files for users and groups
foreach my $u (&list_users(), &list_groups()) {
	if (!$u->{'proto'}) {
		push(@rv, "$config_directory/$u->{'name'}.acl",
			  glob("$config_directory/*/$u->{'name'}.acl"));
		}
	}

# Add /etc/webmin/config
&copy_source_dest("$config_directory/config",
		  "$config_directory/config.aclbackup");
push(@rv, "$config_directory/config.aclbackup");

# Add /etc/webmin/miniserv.conf
&copy_source_dest("$config_directory/miniserv.conf",
		  "$config_directory/miniserv.conf.aclbackup");
push(@rv, "$config_directory/miniserv.conf.aclbackup");

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
unlink("$config_directory/config.aclbackup");
unlink("$config_directory/miniserv.conf.aclbackup");
return undef;
}

# pre_restore(&files)
# Called before the files are restored from a backup
sub pre_restore
{
# Remove user and group .acl files
foreach my $u (&list_users(), &list_groups()) {
	if (!$u->{'proto'}) {
		unlink("$config_directory/$u->{'name'}.acl",
		       glob("$config_directory/*/$u->{'name'}.acl"));
		}
	}
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
# Splice global config entries for users into real config
my %aclbackup;
&read_file("$config_directory/config.aclbackup", \%aclbackup);
unlink("$config_directory/config.aclbackup");
foreach my $k (keys %gconfig) {
	delete($gconfig{$k}) if ($k =~ /^(lang_|notabs_|theme_|ownmods_)/);
	}
foreach my $k (keys %aclbackup) {
	$gconfig{$k} = $aclbackup{$k} if ($k =~ /^(lang_|notabs_|theme_|ownmods_)/);
	}
&write_file("$config_directory/config", \%gconfig);

# Splice miniserv.conf entries for users and password restrictions into
# real config
%aclbackup = ( );
&read_file("$config_directory/miniserv.conf.aclbackup", \%aclbackup);
unlink("$config_directory/miniserv.conf.aclbackup");
my %miniserv;
&get_miniserv_config(\%miniserv);
foreach my $k (keys %miniserv) {
	delete($miniserv{$k}) if ($k =~ /^(preroot_|pass_)/);
	}
foreach my $k (keys %aclbackup) {
	$miniserv{$k} = $aclbackup{$k} if ($k =~ /^(preroot_|pass_)/);
	}
&put_miniserv_config(\%miniserv);

&restart_miniserv();
return undef;
}

1;

