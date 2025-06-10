# install_check.pl

do 'postfix-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-x $config{'postfix_control_command'});
if ($_[0]) {
	return 2 if (!&check_postfix());
	}
return 1;
}

