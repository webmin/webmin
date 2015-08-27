# install_check.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
my ($mode) = @_;
my %first;
&read_file("$config_directory/first-install", \%first);
if ($first{'version'} && $first{'version'} >= 1.762) {
	# For new webmin installs, hide this module
	return 0;
	}
return $mode ? 2 : 1;
}

