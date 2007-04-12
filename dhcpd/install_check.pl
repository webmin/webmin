# install_check.pl

do 'dhcpd-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
local @st = stat($config{'dhcpd_path'});
return 0 if (!@st);
if (!$config{'dhcpd_version'} ||
    $st[7] != $config{'dhcpd_size'} || $st[9] != $config{'dhcpd_mtime'}) {
	# Version is not cached - need to actually check
	return 0 if (!&get_dhcpd_version(\$dummy));
	}
return $_[0] ? 2 : 1;
}

