# install_check.pl

do 'quota-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
# Check the traditional quota-tools dependency when this OS implements it.
if (defined(&quotas_init)) {
	local $err = &quotas_init();
	# A usable Btrfs mount and command provide an alternative when the
	# traditional quota-tools package is not installed.
	if ($err) {
		local @btrfs = &list_btrfs_filesystems();
		return 0 if (!@btrfs || !&has_command("btrfs"));
		}
	}
return $_[0] ? 2 : 1;
}

