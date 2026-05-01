# install_check.pl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

our (%config, $module_config_directory);
do 'nftables-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
my ($mode) = @_;
return 0 if (&check_nftables());
if ($mode) {
    if (!$config{'direct'}) {
        my $file = $config{'save_file'} ||
                   "$module_config_directory/nftables.conf";
        return 1 if (!-s $file);
        }
    return 2;
    }
return 1;
}
