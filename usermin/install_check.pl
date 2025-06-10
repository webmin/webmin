# install_check.pl

do 'usermin-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
if (-r "$config{'usermin_dir'}/miniserv.conf" &&
    !&same_file($config{'usermin_dir'}, $config_directory)) {
	my %miniserv;
	&get_usermin_miniserv_config(\%miniserv);
	if ($miniserv{'root'} && -d $miniserv{'root'}) {
		return $_[0] ? 2 : 1;
		}
	}
return 0;
}

