# install_check.pl

use strict;
use warnings;
do 'grub2-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if GRUB 2 is installed and configured for Webmin,
# 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not.
sub is_installed
{
my ($mode) = @_;
return 0 if (!&grub2_any_installed());
return $mode ? (&grub2_configured() ? 2 : 1) : 1;
}

1;
