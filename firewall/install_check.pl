# install_check.pl

do 'firewall-lib.pl';

# is_installed(mode)
# For mode 1, returns 2 if the server is installed and configured for use by
# Webmin, 1 if installed but not configured, or 0 otherwise.
# For mode 0, returns 1 if installed, 0 if not
sub is_installed
{
return 0 if (&missing_firewall_commands());
local $out = &backquote_command("iptables -n -t filter -L OUTPUT 2>&1");
return 0 if ($?);
if ($_[0]) {
	# Check if init script is setup
	if (!$config{'direct'} &&
	    (defined(&check_iptables) && &check_iptables() ||
	     !-s $iptables_save_file)) {
		return 1;
		}
	return 2;
	}
# Check if another firewall is in use
my @livetables = &get_iptables_save("ip${ipvx}tables-save 2>/dev/null |");
my @fwname = &external_firewall_list(\@livetables);
@fwname = grep { $_ ne 'fail2ban' } @fwname;
return 0 if (@fwname);
return 1;
}

