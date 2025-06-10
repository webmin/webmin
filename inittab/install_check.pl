# install_check.pl

do 'inittab-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
if (-r $config{'inittab_file'}) {
	my @it = &parse_inittab();
	if (scalar(@it)) {
		return $_[0] ? 2 : 1;
		}
	}
return 0;
}

