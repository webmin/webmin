# install_check.pl

do 'procmail-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if Procmail is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
# Check for procmail binary
return 0 if (!&has_command($config{'procmail'}));
if ($_[0]) {
	# Check if configured too
	local ($mod, $err) = &check_mailserver_config();
	return $err ? 1 : 2;
	}
else {
	return 1;
	}
}

