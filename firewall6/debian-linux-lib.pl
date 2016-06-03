# debians-linux-lib.pl
# Deal with debian's ip6tables save file and startup script

if ($gconfig{'os_version'} >= 3.1 &&
    !-r "/etc/init.d/ip6tables" &&
    !-r "/etc/init.d/webmin-ip6tables" &&
    !$config{'force_init'}) {
	# In newer Debians, IPtable is started by the network init script
	$has_new_debian_ip6tables = 1;
	$ip6tables_save_file = "/etc/ip6tables.up.rules";
	}
else {
	# Older Debians use an init script
	$has_debian_ip6tables = -r "/etc/init.d/ip6tables";
	$debian_ip6tables_dir = "/var/lib/ip6tables";
	if ($has_debian_ip6tables) {
		mkdir($debian_ip6tables_dir, 0755) if (!-d $debian_ip6tables_dir);
		$ip6tables_save_file = "$debian_ip6tables_dir/active";
		}
	}

# apply_ip6tables()
# Applies the current ip6tables configuration from the save file
sub apply_ip6tables
{
if ($has_debian_ip6tables) {
	local $out = &backquote_logged("cd / ; /etc/init.d/ip6tables start 2>&1");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &ip6tables_restore();
	}
}

# unapply_ip6tables()
# Writes the current ip6tables configuration to the save file
sub unapply_ip6tables
{
if ($has_debian_ip6tables) {
	$out = &backquote_logged("cd / ; /etc/init.d/ip6tables save active 2>&1 </dev/null");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &ip6tables_save();
	}
}

# started_at_boot()
sub started_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_ip6tables) {
	# Check Debian init script
	return &init::action_status("ip6tables") == 2;
	}
elsif ($has_new_debian_ip6tables) {
	# Check network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	foreach my $o (@{$debpri->[3]}) {
		if (($o->[0] eq "pre-up" || $o->[0] eq "post-up") &&
		    $o->[1] =~ /\S*ip6tables-restore\s+<\s+(\S+)/ &&
		    $1 eq $ip6tables_save_file) {
			return 1;
			}
		}
	}
else {
	# Check Webmin init script
	return &init::action_status("webmin-ip6tables") == 2;
	}
}

sub enable_at_boot
{
&foreign_require("init", "init-lib.pl");
if ($has_debian_ip6tables) {
	&init::enable_at_boot("ip6tables");	 # Assumes init script exists
	}
elsif ($has_new_debian_ip6tables) {
	# Add to network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	if ($debpri && !&started_at_boot()) {
		push(@{$debpri->[3]},
		     [ "post-up", "ip6tables-restore < $ip6tables_save_file" ]);
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
if ($has_debian_ip6tables) {
	&init::disable_at_boot("ip6tables");
	}
elsif ($has_new_debian_ip6tables) {
	# Remove from network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	@{$debpri->[3]} = grep {
			($_->[0] ne "pre-up" && $_->[0] ne "post-up") ||
			 $_->[1] !~ /^\S*ip6tables/ } @{$debpri->[3]};
	&net::modify_interface_def(@$debpri);
	}
else {
	&init::disable_at_boot("webmin-ip6tables");
	}
}

sub get_primary_network_interface
{
&foreign_require("net", "net-lib.pl");
local @boot = sort { $a->{'fullname'} cmp $b->{'fullname'} }
		   &net::boot_interfaces();
local ($eth) = grep { $_->{'fullname'} =~ /^eth\d+$/ } @boot;
local ($ppp) = grep { $_->{'fullname'} =~ /^ppp\d+$/ } @boot;
local ($venetn) = grep { $_->{'fullname'} =~ /^venet\d+:\d+$/ } @boot;
local ($venet) = grep { $_->{'fullname'} =~ /^venet\d+$/ } @boot;
return $eth || $ppp || $venetn || $venet || $boot[0];
}

1;

