# install_check.pl

do 'ldap-useradmin-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
if ($config{'auth_ldap'}) {
	return 0 if (!-r $config{'auth_ldap'});
	}
else {
	if ($_[0]) {
		return 1 if (!$config{'ldap_host'} || !$config{'login'} ||
			     !$config{'pass'} || !$config{'user_base'} ||
			     !$config{'group_base'});
		}
	}
if ($_[0]) {
	return 2 if ($got_net_ldap);
	}
return 1;
}

