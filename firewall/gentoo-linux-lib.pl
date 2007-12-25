# gentoo-linux-lib.pl
# Deal with gentoo's IPtables save file

# check_iptables()
# Returns an error message if something is wrong with iptables on this system
sub check_iptables
{
if (!-r "/etc/init.d/iptables") {
	return &text('gentoo_escript', "<tt>/etc/init.d/iptables</tt>");
	}
return undef;
}

local %iptconf;
&read_env_file("/etc/conf.d/iptables", \%iptconf);
$iptables_save_file = $iptconf{'IPTABLES_SAVE'};

# apply_iptables()
# Applies the current iptables configuration from the save file
sub apply_iptables
{
local $out = &backquote_logged("cd / ; /etc/init.d/iptables reload 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

1;

