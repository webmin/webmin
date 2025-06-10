# install_check.pl

do 'ipfw-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!&has_command($config{'ipfw'}));
local $ex = system("$config{'ipfw'} list >/dev/null 2>&1 </dev/null");
return 0 if ($ex);
if ($_[0]) {
	local $rules = &get_config();
	return 2 if (@$rules);
	}
return 1;
}

