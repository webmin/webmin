# debians-linux-lib.pl
# Deal with debian's iptables save file and startup script

if ($gconfig{'os_version'} >= 3.1 &&
    !-r "/etc/init.d/iptables" &&
    !-r "/etc/init.d/webmin-iptables") {
	# In newer Debians, IPtable is started by the network init script
	$has_new_debian_iptables = 1;
	$iptables_save_file = "/etc/iptables.up.rules";
	}
else {
	# Older Debians use an init script
	$has_debian_iptables = -r "/etc/init.d/iptables";
	$debian_iptables_dir = "/var/lib/iptables";
	if ($has_debian_iptables) {
		mkdir($debian_iptables_dir, 0755) if (!-d $debian_iptables_dir);
		$iptables_save_file = "$debian_iptables_dir/active";
		}
	}

# apply_iptables()
# Applies the current iptables configuration from the save file
sub apply_iptables
{
if ($has_debian_iptables) {
	local $out = &backquote_logged("cd / ; /etc/init.d/iptables start 2>&1");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &iptables_restore();
	}
}

# unapply_iptables()
# Writes the current iptables configuration to the save file
sub unapply_iptables
{
if ($has_debian_iptables) {
	$out = &backquote_logged("cd / ; /etc/init.d/iptables save active 2>&1 </dev/null");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &iptables_save();
	}
}

# started_at_boot()
sub started_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_iptables) {
	# Check Debian init script
	return &init::action_status("iptables") == 2;
	}
elsif ($has_new_debian_iptables) {
	# Check network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	foreach my $o (@{$debpri->[3]}) {
		if (($o->[0] eq "pre-up" || $o->[0] eq "post-up") &&
		    $o->[1] =~ /\S*iptables-restore\s+<\s+(\S+)/ &&
		    $1 eq $iptables_save_file) {
			return 1;
			}
		}
	}
else {
	# Check Webmin init script
	return &init::action_status("webmin-iptables") == 2;
	}
}

sub enable_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_iptables) {
	&init::enable_at_boot("iptables");	 # Assumes init script exists
	}
elsif ($has_new_debian_iptables) {
	# Add to network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	if ($debpri && !&started_at_boot()) {
		push(@{$debpri->[3]},
		     [ "post-up", "iptables-restore < $iptables_save_file" ]);
		&net::modify_interface_def(@$debpri);
		}
	}
else {
	&create_webmin_init();
	}
}

sub disable_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_iptables) {
	&init::disable_at_boot("iptables");
	}
elsif ($has_new_debian_iptables) {
	# Remove from network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	@{$debpri->[3]} = grep {
			($_->[0] ne "pre-up" && $_->[0] ne "post-up") ||
			 $_->[1] !~ /^\S*iptables/ } @{$debpri->[3]};
	&net::modify_interface_def(@$debpri);
	}
else {
	&init::disable_at_boot("webmin-iptables");
	}
}

sub get_primary_network_interface
{
&foreign_require("net", "net-lib.pl");
local @boot = sort { $a->{'fullname'} cmp $b->{'fullname'} }
		   &net::boot_interfaces();
local ($eth) = grep { $_->{'fullname'} =~ /^eth\d+$/ } @boot;
local ($ppp) = grep { $_->{'fullname'} =~ /^ppp\d+$/ } @boot;
return $eth || $ppp || $boot[0];
}

1;

