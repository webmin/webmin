# install_check.pl

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
do 'squid-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
my ($mode) = @_;
return 0 if (!-r $config{'squid_conf'} || !&has_command($config{'squid_path'}));
if ($mode) {
	# Check if cache is ready
	my @dummy;
	return 2 if (&check_cache(&get_config(), \@dummy));
	}
return 1;
}

