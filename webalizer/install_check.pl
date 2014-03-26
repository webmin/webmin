# install_check.pl

use strict;
use warnings;
our (%config);
do 'webalizer-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!&has_command($config{'webalizer'}));
my $dummy;
my $ver = &get_webalizer_version(\$dummy);
$ver =~ s/\-.*$//;
return 0 if (!$ver || $ver < 2);
return $_[0] ? 2 : 1;
}

