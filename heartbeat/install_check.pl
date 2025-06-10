# install_check.pl

do 'heartbeat-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-d $config{'ha_dir'});
return 0 if (!-r $ha_cf && !-r $config{'alt_ha_cf'} ||
	     !-r $haresources && !-r $config{'alt_haresources'} ||
	     !-r $authkeys && !-r $config{'alt_authkeys'});
if ($_[0]) {
	return 2 if (-r $ha_cf && -r $haresources && -r $authkeys);
	}
return 1;
}

