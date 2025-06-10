# gentoo-linux-lib.pl
# Deal with gentoo's iptables save file

# check_iptables()
# Returns an error message if something is wrong with iptables on this system
sub check_iptables
{
if (!-r "/etc/init.d/ip${ipvx}tables") {
	return &text('gentoo_escript', "<tt>/etc/init.d/ip${ipvx}tables</tt>");
	}
return undef;
}

local %iptconf;
&read_env_file("/etc/conf.d/ip${ipvx}tables", \%iptconf);
$ip6tables_save_file = $iptconf{'ip6tables_SAVE'};
$iptables_save_file = $iptconf{'iptables_SAVE'};

# apply_iptables()
# Applies the current iptables configuration from the save file
sub apply_iptables
{
local $out = &backquote_logged("cd / ; /etc/init.d/ip${ipvx}tables reload 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

1;

