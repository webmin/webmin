# install_check.pl

use strict;
use warnings;
do 'firewalld-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
my ($mode) = @_;
return 0 if (&check_firewalld());
if ($mode) {
	return &is_firewalld_running() ? 2 : 1;
	}
return 1;
}

