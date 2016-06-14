# install_check.pl
use strict;
use warnings;
our (%config);

do 'bind8-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-x $config{'named_path'});
return 0 if (&check_bind_8());
if ($_[0]) {
	return 2 if (-r &make_chroot($config{'named_conf'}) &&
		     &is_config_valid());
	}
return 1;
}

