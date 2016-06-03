# redhat-linux-lib.pl
# Deal with redhat's /etc/sysconfig/ip6tables save file and startup script

&foreign_require("init", "init-lib.pl");
$init_script = "$init::config{'init_dir'}/ip6tables";

# check_ip6tables()
# Returns an error message if something is wrong with ip6tables on this system
sub check_ip6tables
{
&foreign_require("init");
&init::action_status("ip6tables") > 0 || return $text{'redhat_einstalled'};
return undef if ($gconfig{'os_type'} eq 'trustix-linux');
return undef if ($gconfig{'os_type'} eq 'redhat-linux' &&
		 $gconfig{'os_version'} > 10);
if (!$config{'done_check_ip6tables'} && -r $init_script) {
	local $out = &backquote_command("$init_script status 2>&1");
	if ($out !~ /table:|INPUT|FORWARD|OUTPUT|is\s+stopped|firewall\s+stopped/) {
		return &text('redhat_eoutput',
			     "<tt>$init_script status</tt>");
		}
	$config{'done_check_ip6tables'} = 1;
	&save_module_config();
	}
return undef;
}

$ip6tables_save_file = "/etc/sysconfig/ip6tables";

# apply_ip6tables()
# Applies the current ip6tables configuration from the save file
sub apply_ip6tables
{
if (-r $init_script) {
	local $out = &backquote_logged("cd / ; $init_script restart 2>&1");
	$out =~ s/\033[^m]+m//g;
	return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
	}
else {
	local $out = &backquote_logged("cd ; service ip6tables restart 2>&1");
	return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
	}
}

# unapply_ip6tables()
# Writes the current ip6tables configuration to the save file
sub unapply_ip6tables
{
if (-r $init_script) {
	$out = &backquote_logged("cd / ; $init_script save 2>&1 </dev/null");
	$out =~ s/\033[^m]+m//g;
	if ($? && $out =~ /usage/i) {
		# 'save' argument not supported .. call ip6tables-save manually
		return &ip6tables_save();
		}
	return $? || $out =~ /FAILED/ ? "<pre>$out</pre>" : undef;
	}
else {
	return &ip6tables_save();
	}
}

# started_at_boot()
sub started_at_boot
{
return &init::action_status("ip6tables") == 2;
}

sub enable_at_boot
{
&init::enable_at_boot("ip6tables");	 # Assumes init script exists
}

sub disable_at_boot
{
&init::disable_at_boot("ip6tables");
}

1;

