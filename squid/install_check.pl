# install_check.pl

do 'squid-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-r $config{'squid_conf'} || !&has_command($config{'squid_path'}));
if ($_[0]) {
	# Check if cache is ready
	return 2 if (&check_cache(&get_config(), \@dummy));
	}
return 1;
}

