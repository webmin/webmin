# redhat-linux-lib.pl
# Deal with redhat's /etc/sysconfig/iptables save file and startup script

# check_iptables()
# Returns an error message if something is wrong with iptables on this system
sub check_iptables
{
if (!-r "/etc/rc.d/init.d/iptables") {
	return &text('redhat_escript', "<tt>/etc/rc.d/init.d/iptables</tt>");
	}
if (!$config{'done_check_iptables'}) {
	local $out = `/etc/rc.d/init.d/iptables status 2>&1`;
	if ($out !~ /table:|INPUT|FORWARD|OUTPUT/) {
		return &text('redhat_eoutput',
			     "<tt>/etc/init.d/iptables status</tt>");
		}
	$config{'done_check_iptables'} = 1;
	&save_module_config();
	}
return undef;
}

$iptables_save_file = "/etc/sysconfig/iptables";

# apply_iptables()
# Applies the current iptables configuration from the save file
#sub apply_iptables
#{
#local $out = &backquote_logged("cd / ; /etc/rc.d/init.d/iptables restart 2>&1");
#$out =~ s/\033[^m]+m//g;
#return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
#}

# unapply_iptables()
# Writes the current iptables configuration to the save file
sub unapply_iptables
{
$out = &backquote_logged("cd / ; /etc/rc.d/init.d/iptables save 2>&1 </dev/null");
$out =~ s/\033[^m]+m//g;
return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
}

# started_at_boot()
sub started_at_boot
{
&foreign_require("init", "init-lib.pl");
return &init::action_status("iptables") == 2;
}

sub enable_at_boot
{
&foreign_require("init", "init-lib.pl");
&init::enable_at_boot("iptables");	 # Assumes init script exists
}

sub disable_at_boot
{
&foreign_require("init", "init-lib.pl");
&init::disable_at_boot("iptables");
}

1;

