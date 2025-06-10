# install_check.pl

do 'postgresql-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-x $config{'psql'});
if ($_[0]) {
	# Check for .conf and if can login
	return 1 if (!-r $hba_conf_file && &is_postgresql_local());
	return 2 if (&is_postgresql_running() == 1);
	}
return 1;
}

