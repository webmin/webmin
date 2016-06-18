use strict;
use warnings;
our %config;

do 'at-lib.pl';

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
my @rv;
opendir(my $DIR, $config{'at_dir'});
while(my $f = readdir($DIR)) {
	next if ($f eq "." || $f eq ".." || $f eq ".SEQ");
	if (!-d "$config{'at_dir'}/$f") {
		push(@rv, "$config{'at_dir'}/$f");
		}
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
return undef;
}

1;

