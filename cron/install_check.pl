# install_check.pl

do 'cron-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
if (-d $config{'cron_dir'} || &has_command("crontab") ||
    -r $config{'single_file'}) {
	return $_[0] ? 2 : 1;
	}
return 0;
}

