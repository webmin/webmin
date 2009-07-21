# install_check.pl

do 'bacula-backup-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
local $err = &check_bacula();
return 0 if ($err);
if (&has_bacula_dir() && $_[1]) {
	eval { my $dbh = &connect_to_database(); };
	return $@ ? 1 : 2;
	}
return $_[1] ? 2 : 1;
}

