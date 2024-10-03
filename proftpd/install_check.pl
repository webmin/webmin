# install_check.pl

do 'proftpd-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
my ($mode) = @_;
return 0 if (!-x $config{'proftpd_path'} || !-r $config{'proftpd_conf'});
if ($mode) {
	return 2 if ($site{'version'} || &get_proftpd_version());
	}
return 1;
}

