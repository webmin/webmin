
do 'sendmail-lib.pl';
do 'aliases-lib.pl';
do 'virtusers-lib.pl';
do 'mailers-lib.pl';
do 'generics-lib.pl';
do 'domain-lib.pl';
do 'access-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
# Add main config file
local @rv = ( $config{'sendmail_cf'} );
local $conf = &get_sendmailcf();

# Add files references in .cf
local $f;
foreach $f (&find_type("F", $conf)) {
	if ($f->{'value'} =~ /^[wMtGR][^\/]*(\/\S+)/ ||
	    $f->{'value'} =~ /^\{[wMtGR]\}[^\/]*(\/\S+)/) {
		push(@rv, $1);
		}
	}

# Add other maps
local $afiles = &aliases_file($conf);
push(@rv, @$afiles);
local $vfile = &virtusers_file($conf);
push(@rv, $vfile) if ($vfile);
local $mfile = &mailers_file($conf);
push(@rv, $mfile) if ($mfile);
local $gfile = &generics_file($conf);
push(@rv, $gfile) if ($gfile);
local $dfile = &domains_file($conf);
push(@rv, $dfile) if ($dfile);
local $afile = &access_file($conf);
push(@rv, $afile) if ($afile);

# Add .m4 files
push(@rv, $config{'sendmail_mc'}) if ($config{'sendmail_mc'});

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
&restart_sendmail();
return undef;
}

1;

