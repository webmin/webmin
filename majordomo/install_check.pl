# install_check.pl

do 'majordomo-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-r $config{'majordomo_cf'} || !-d $config{'program_dir'} ||
	     !-r "$config{'program_dir'}/majordomo_version.pl");
require "$config{'program_dir'}/majordomo_version.pl";
return 0 if ($majordomo_version < 1.94 || $majordomo_version >= 2);
if ($_[0]) {
	local $conf = &get_config();
	return 2 if (&homedir_valid($conf));
	}
return 1;
}

