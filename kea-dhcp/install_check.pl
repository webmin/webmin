# install_check.pl

use strict;
use warnings;
do 'kea-dhcp-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if Kea is installed and configured for use by Webmin,
# 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not.
sub is_installed
{
# Webmin mode 1 distinguishes installed-but-unconfigured from ready-to-use.
return 0 if (!&kea_any_installed());
return $_[0] ? (&kea_any_configured() ? 2 : 1) : 1;
}

1;
