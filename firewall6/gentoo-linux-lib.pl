# gentoo-linux-lib.pl
# Deal with gentoo's ip6tables save file

# check_ip6tables()
# Returns an error message if something is wrong with ip6tables on this system
sub check_ip6tables
{
if (!-r "/etc/init.d/ip6tables") {
	return &text('gentoo_escript', "<tt>/etc/init.d/ip6tables</tt>");
	}
return undef;
}

local %iptconf;
&read_env_file("/etc/conf.d/ip6tables", \%iptconf);
$ip6tables_save_file = $iptconf{'ip6tables_SAVE'};

# apply_ip6tables()
# Applies the current ip6tables configuration from the save file
sub apply_ip6tables
{
local $out = &backquote_logged("cd / ; /etc/init.d/ip6tables reload 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

1;

