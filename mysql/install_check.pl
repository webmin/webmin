# install_check.pl

do 'mysql-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-x $config{'mysqladmin'} || !-x $config{'mysql'});
return 0 if (&is_mysql_local() && $config{'my_cnf'} && !-r $config{'my_cnf'});
return 0 if (&get_mysql_version(\$dummy) <= 0);
if ($_[0]) {
	# Check if can login
	return 2 if (&is_mysql_running() == 1);
	}
return 1;
}

