# install_check.pl

do 'phpini-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return &get_default_php_ini() ||
       &has_command("php") ||
       &has_command("php4") ||
       &has_command("php5") ||
       &has_command("php-cgi") ||
       &has_command("php4-cgi") ||
       &has_command("php5-cgi");
}

