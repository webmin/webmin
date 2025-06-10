# install_check.pl

do 'spam-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!&has_command($config{'spamassassin'}));
return 0 if (!&get_spamassassin_version(\$dummy));
return 0 if (!-r $local_cf);
return $_[0] ? 2 : 1;
}

