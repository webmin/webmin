# install_check.pl

do 'apache-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if Apache is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!-d $config{'httpd_dir'} || !&find_httpd());
local ($htconf) = &find_httpd_conf();
return 0 if (!$htconf);
if ($_[0]) {
	return 2 if ($httpd_modules{'core'});
	}
return 1;
}

