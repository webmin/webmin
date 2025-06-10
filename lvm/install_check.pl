# install_check.pl

do 'lvm-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (!&has_command("vgdisplay"));
local $out = `vgdisplay --version 2>&1`;
if ($out =~ /\s+([0-9\.]+)/ && $1 < 2) {
	if (!-d $lvm_proc) {
		system("modprobe lvm-mod >/dev/null 2>&1");
		}
	return 0 if (!-d $lvm_proc);
	}
return $_[0] ? 2 : 1;
}

