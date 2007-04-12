# install_check.pl

do 'jabber-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-r $config{'jabber_config'} ||
	     !-d $config{'jabber_dir'});
local $jabberd = $config{'jabber_daemon'} ? $config{'jabber_daemon'}
				    	  : "$config{'jabber_dir'}/bin/jabberd";
return 0 if (!-x $jabberd || !&get_jabberd_version(\$dummy));
if ($_[0]) {
	return 2 if ($got_xml_parser && $got_xml_generator);
	}
return 1;
}

