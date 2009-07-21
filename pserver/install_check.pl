# install_check.pl

do 'pserver-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!$cvs_path || !&get_cvs_version(\$dummy));
if ($_[0]) {
	return 2 if (-d "$config{'cvsroot'}/CVSROOT");
	}
return 1;
}

