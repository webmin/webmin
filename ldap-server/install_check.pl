# install_check.pl

do 'ldap-server-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
local $local = &local_ldap_server();
return 0 if ($local < 0);
if ($_[0]) {
	# Also check for DB connection
	local $ldap = &connect_ldap_db();
	return ref($ldap) ? 2 : 1;
	}
else {
	return 1;
	}
}

