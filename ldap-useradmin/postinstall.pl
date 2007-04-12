
require 'ldap-useradmin-lib.pl';

# Set quota_support if quota is set
sub module_install
{
if (!defined($config{'quota_support'})) {
	$config{'quota_support'} = $config{'quota'} eq '' ? 0 : 1;
	&save_module_config();
	}
}

