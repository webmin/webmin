# install_check.pl

do 'ldap-useradmin-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
my $cfile = &ldap_client::get_ldap_config_file();
if ($cfile) {
	return 0 if (!-r $cfile);
	}
elsif ($_[0]) {
	return 1 if (!$config{'ldap_host'} || !$config{'login'} ||
		     (!$config{'pass'} && !$config{'ldap_pass_file'}) || 
		     !$config{'user_base'} || !$config{'group_base'});
	}
if ($_[0]) {
	return 2 if ($got_net_ldap);
	}
return 1;
}

