# redhat-linux-lib.pl
# Deal with redhat's /etc/sysconfig/iptables save file and startup script

&foreign_require("init", "init-lib.pl");
$init_script = "$init::config{'init_dir'}/iptables";

# check_iptables()
# Returns an error message if something is wrong with iptables on this system
sub check_iptables
{
if (!-r $init_script &&
    &backquote_command("service iptables status 2>/dev/null") !~ /Loaded:\s+loaded/) {
	return &text('redhat_escript', "<tt>$init_script</tt>");
	}
return undef if ($gconfig{'os_type'} eq 'trustix-linux');
return undef if ($gconfig{'os_type'} eq 'redhat-linux' &&
		 $gconfig{'os_version'} > 10);
if (!$config{'done_check_iptables'}) {
	local $out = `$init_script status 2>&1`;
	if ($out !~ /table:|INPUT|FORWARD|OUTPUT|is\s+stopped|firewall\s+stopped/) {
		return &text('redhat_eoutput',
			     "<tt>$init_script status</tt>");
		}
	$config{'done_check_iptables'} = 1;
	&save_module_config();
	}
return undef;
}

$iptables_save_file = "/etc/sysconfig/iptables";

# apply_iptables()
# Applies the current iptables configuration from the save file
sub apply_iptables
{
if (-r $init_script) {
	local $out = &backquote_logged("cd / ; $init_script restart 2>&1");
	$out =~ s/\033[^m]+m//g;
	return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
	}
else {
	local $out = &backquote_logged("cd ; service iptables restart 2>&1");
	return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
	}
}

# unapply_iptables()
# Writes the current iptables configuration to the save file
sub unapply_iptables
{
if (-r $init_script) {
	$out = &backquote_logged("cd / ; $init_script save 2>&1 </dev/null");
	$out =~ s/\033[^m]+m//g;
	if ($? && $out =~ /usage/i) {
		# 'save' argument not supported .. call iptables-save manually
		return &iptables_save();
		}
	return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
	}
else {
	return &iptables_save();
	}
}

# started_at_boot()
sub started_at_boot
{
return &init::action_status("iptables") == 2;
}

sub enable_at_boot
{
&init::enable_at_boot("iptables");	 # Assumes init script exists
}

sub disable_at_boot
{
&init::disable_at_boot("iptables");
}

1;

