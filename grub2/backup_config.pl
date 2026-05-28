use strict;
use warnings;

do 'grub2-lib.pl';

# backup_config_files()
# Returns GRUB 2 files and directories that can be backed up.
sub backup_config_files
{
return &grub2_config_files();
}

1;
