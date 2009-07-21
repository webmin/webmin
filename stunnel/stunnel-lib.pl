# stunnel-lib.pl
# Common functions for accessing inetd or xinetd

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

if ($config{'stunnel_path'} =~ /([^\/]+)$/) {
	$stunnel_shortname = $1;
	}
$webmin_pem = "$config_directory/miniserv.pem";

if (&foreign_check("inetd")) {
	&foreign_require("inetd", "inetd-lib.pl");
	$has_inetd = 1;
	}
if (&foreign_check("xinetd")) {
	&foreign_require("xinetd", "xinetd-lib.pl");
	$has_xinetd = 1;
	}

# list_stunnels()
# Search the inetd and xinetd configurations for stunnel lines
sub list_stunnels
{
local @rv;
if ($has_inetd) {
	# List tunnels from inetd.conf
	local %portmap;
	foreach $s (&foreign_call("inetd", "list_services")) {
		$portmap{$s->[1]} = $s;
		foreach $a (split(/\s+/, $s->[4])) {
			$portmap{$a} = $s;
			}
		}
	foreach $i (&foreign_call("inetd", "list_inets")) {
		if ($i->[8] eq $config{'stunnel_path'} ||
		    $i->[8] eq $stunnel_shortname) {
			push(@rv, { 'type' => 'inetd',
				    'name' => $i->[3],
				    'port' => $portmap{$i->[3]}->[2],
				    'user' => $i->[7],
				    'active' => $i->[1],
				    'command' => $i->[8],
				    'args' => $i->[9],
				    'index' => scalar(@rv),
				    'file' => $i->[10],
				    'line' => $i->[0] });
			}
		}
	}
if ($has_xinetd) {
	# List tunnels from xinetd.conf
	foreach $x (&foreign_call("xinetd", "get_xinetd_config")) {
		next if ($x->{'name'} ne 'service');
		local $q = $x->{'quick'};
		if ($q->{'server'}->[0] eq $config{'stunnel_path'} ||
		    $q->{'server'}->[0] eq $stunnel_shortname) {
			push(@rv, { 'type' => 'xinetd',
				    'name' => $x->{'value'},
				    'port' => &xinet_port($x),
				    'active' => $q->{'disable'}->[0] ne 'yes',
				    'command' => $q->{'server'}->[0],
				    'args' => join(" ", $q->{'server'}->[0],
						@{$q->{'server_args'}}),
				    'index' => scalar(@rv),
				    'file' => $x->{'file'},
				    'xindex' => $x->{'index'} } );
			}
		}
	}
return @rv;
}

# create_tunnel(&tunnel)
sub create_stunnel
{
local ($pclash, $nclash);
if ($has_xinetd) {
	# Check for xinet clash
	foreach $x (&foreign_call("xinetd", "get_xinetd_config")) {
		next if ($x->{'name'} ne 'service');
		local $q = $x->{'quick'};
		&error(&text('save_exinetd', $_[0]->{'name'}))
			if ($x->{'value'} eq $_[0]->{'name'});
		&error(&text('save_export', $_[0]->{'port'}, $x->{'value'}))
			if (&xinet_port($x) == $_[0]->{'port'});
		}
	}
if ($has_inetd) {
	# Check if there is already a service for the port or with the name
	($pclash, $nclash) = &find_clashes($_[0]->{'name'}, $_[0]->{'port'});
	if (!$pclash && $nclash) {
		# The name is taken, but on a different port
		&error(&text('save_enclash', $nclash->[2], $nclash->[1]));
		}
	local $iname = $pclash ? $pclash->[1] : $_[0]->{'name'};

	# Check if there is an inetd entry on the name
	foreach $i (&foreign_call("inetd", "list_inets")) {
		&error(&text('save_einetd', $iname))
			if ($i->[3] eq $iname);
		}
	}

local $addto = $_[0]->{'type'} ? $_[0]->{'type'} :
	       $has_xinetd ? "xinetd" : "inetd";
if ($addto eq 'xinetd') {
	# Just add to xinetd.conf with a custom name and port
	local $xinet = { 'name' => 'service',
			 'values' => [ $_[0]->{'name'} ] };
	&foreign_call("xinetd", "set_member_value", $xinet, "port",
		      $_[0]->{'port'});
	&foreign_call("xinetd", "set_member_value", $xinet, "socket_type",
		      "stream");
	&foreign_call("xinetd", "set_member_value", $xinet, "protocol",
		      "tcp");
	&foreign_call("xinetd", "set_member_value", $xinet, "user",
		      "root");
	&foreign_call("xinetd", "set_member_value", $xinet, "wait",
		      "no");
	&foreign_call("xinetd", "set_member_value", $xinet, "disable",
		      $_[0]->{'active'} ? "no" : "yes");
	&foreign_call("xinetd", "set_member_value", $xinet, "type",
		      "UNLISTED");
	&foreign_call("xinetd", "set_member_value", $xinet, "server",
		      $_[0]->{'command'});
	local $args = $_[0]->{'args'};
	$args =~ s/^\S+\s+//;
	&foreign_call("xinetd", "set_member_value", $xinet, "server_args",
		      $args);
	&foreign_call("xinetd", "create_xinet", $xinet);
	}
elsif ($addto eq 'inetd') {
	if ($pclash) {
		# Use existing /etc/services entry
		$_[0]->{'name'} = $pclash->[1];
		}
	else {
		# Create /etc/services entry
		&foreign_call("inetd", "create_service", $_[0]->{'name'},
			      $_[0]->{'port'}, "tcp", undef);
		}
	# Create inetd.conf entry
	&foreign_call("inetd", "create_inet", $_[0]->{'active'},
		      $_[0]->{'name'}, "stream", "tcp", "nowait", "root",
		      $_[0]->{'command'}, $_[0]->{'args'});
	}
}

# delete_stunnel(&tunnel)
sub delete_stunnel
{
if ($_[0]->{'type'} eq 'inetd') {
	# Delete from inetd.conf
	&foreign_call("inetd", "delete_inet", $_[0]->{'line'}, $_[0]->{'file'});
	if ($_[0]->{'port'} >= 1024) {
		# Delete the /etc/services entry as well
		local ($oserv) = &find_clashes($_[0]->{'name'},
					       $_[0]->{'port'});
		&foreign_call("inetd", "delete_service", $oserv->[0]);
		}
	}
elsif ($_[0]->{'type'} eq 'xinetd') {
	# Delete from xinetd
	local @xinets = &foreign_call("xinetd", "get_xinetd_config");
	local $xinet = $xinets[$_[0]->{'xindex'}];
	&foreign_call("xinetd", "delete_xinet", $xinet);
	}
}

# modify_stunnel(&oldtunnel, &newtunnel)
sub modify_stunnel
{
if ($_[0]->{'type'} eq 'inetd') {
	# Check if the name or port has changed
	local ($pclash, $nclash) =
		&find_clashes($_[1]->{'name'}, $_[1]->{'port'});
	local ($oserv) = &find_clashes($_[0]->{'name'}, $_[0]->{'port'});
	if ($_[0]->{'name'} ne $_[1]->{'name'}) {
		# The name has changed
		if ($nclash) {
			&error(&text('save_enclash', $nclash->[2],
						     $_[1]->{'name'}));
			}
		}
	if ($_[0]->{'port'} != $_[1]->{'port'}) {
		# The port has changed ..
		if ($pclash) {
			&error(&text('save_epclash', $_[1]->{'port'},
						     $pclash->[1]));
			}
		}
	&foreign_call("inetd", "modify_service", $oserv->[0],
		      $_[1]->{'name'}, $_[1]->{'port'}, $oserv->[3],
		      $oserv->[4]);

	# Update inetd.conf
	local @inets = &foreign_call("inetd", "list_inets");
	local ($oi) = grep { $_->[0] eq $_[0]->{'line'} &&
			     $_->[10] eq $_[0]->{'file'} } @inets;
	&foreign_call("inetd", "modify_inet", $oi->[0],
		      $_[1]->{'active'}, $_[1]->{'name'}, $oi->[4],
		      $oi->[5], $oi->[6], $oi->[7], $oi->[8],
		      $_[1]->{'args'}, $oi->[10]);
	}
elsif ($_[0]->{'type'} eq 'xinetd') {
	# Get the old xinetd config
	local @xinets = &foreign_call("xinetd", "get_xinetd_config");
	local $xinet = $xinets[$_[0]->{'xindex'}];

	# Check for name clash
	if ($_[0]->{'name'} ne $_[1]->{'name'}) {
		foreach $x (@xinets) {
			next if ($x->{'name'} ne 'service');
			&error(&text('save_exinetd', $_[1]->{'name'}))
				if ($x->{'value'} eq $_[1]->{'name'});
			}
		}

	# Check for port clash
	 if ($_[0]->{'port'} != $_[1]->{'port'}) {
		foreach $x (@xinets) {
			next if ($x->{'name'} ne 'service');
			&error(&text('save_export', $_[1]->{'port'},
						    $x->{'value'}))
				if (&xinet_port($x) == $_[1]->{'port'});
			}
		}

	# If name or port has changed, convert to an UNLISTED service
	if ($_[0]->{'name'} ne $_[1]->{'name'} ||
	    $_[0]->{'port'} != $_[1]->{'port'}) {
		$xinet->{'values'} = [ $_[1]->{'name'} ];
		&foreign_call("xinetd", "set_member_value", $xinet, "port",
			      $_[1]->{'port'});
		&foreign_call("xinetd", "set_member_value", $xinet, "type",
			      "UNLISTED");
		}

	&foreign_call("xinetd", "set_member_value", $xinet, "disable",
		      $_[1]->{'active'} ? "no" : "yes");
	&foreign_call("xinetd", "set_member_value", $xinet, "server",
		      $_[1]->{'command'});
	local $args = $_[1]->{'args'};
	$args =~ s/^\S+\s+//;
	&foreign_call("xinetd", "set_member_value", $xinet, "server_args",
		      $args);
	&foreign_call("xinetd", "modify_xinet", $xinet);
	}
}

# find_clashes(name, port)
sub find_clashes
{
local ($pclash, $nclash);
foreach $s (&foreign_call("inetd", "list_services")) {
	local @aliases = split(/\s+/, $s->[4]);
	$pclash = $s if ($s->[2] == $_[1]);
	$nclash = $s if ($s->[1] eq $_[0] || &indexof($_[0], @aliases) >= 0);
	}
return ($pclash, $nclash);
}

# xinet_port(&xinet)
sub xinet_port
{
local $q = $_[0]->{'quick'};
local $p = $q->{'port'};
return $p->[0] if ($p);
local @s = getservbyname($_[0]->{'value'}, $q->{'protocol'}->[0]);
return $s[2];
}

# lock_create_file()
# Lock the file to which new tunnels will be added
sub lock_create_file
{
if ($has_xinetd) {
	local %iconfig = &foreign_config("xinetd");
	&lock_file($iconfig{'xinetd_conf'});
	}
elsif ($has_inetd) {
	local %iconfig = &foreign_config("inetd");
	&lock_file($iconfig{'inetd_conf_file'});
	}
}

# get_stunnel_version(&out)
sub get_stunnel_version
{
local $out = `$config{'stunnel_path'} -V 2>&1`;
if ($?) {
	$out = `$config{'stunnel_path'} -version 2>&1`;
	}
${$_[0]} = $out;
return $out =~ /stunnel\s+(\S+)/ ? $1 : undef;
}

# get_stunnel_config(file)
# Returns an array of stunnel configuration sections, each of which is a hash
# reference containing the actual settings
sub get_stunnel_config
{
local (@rv, $service);
push(@rv, $service = { 'line' => 0, 'eline' => 0, 'values' => { } });
local $lnum = 0;
open(CONF, $_[0]);
while(<CONF>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^\s*\[(.*)\]/) {
		push(@rv, $service = { 'name' => $1,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'values' => { } });
		}
	elsif (/^\s*(\S+)\s*=\s*(.*)/) {
		$service->{'eline'} = $lnum;
		$service->{'values'}->{lc($1)} = $2;
		}
	$lnum++;
	}
close(CONF);
return @rv;
}

# create_stunnel_service(&service, file)
# Creates a service in an stunnel config file
sub create_stunnel_service
{
local $lref = &read_file_lines($_[1]);
push(@$lref, &stunnel_lines($_[0]));
&flush_file_lines();
}

# modify_stunnel_service(&service, file)
# Modifies an existing service in an stunnel config file
sub modify_stunnel_service
{
local $lref = &read_file_lines($_[1]);
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &stunnel_lines($_[0]));
&flush_file_lines();
}

# stunnel_lines(&service)
sub stunnel_lines
{
local @rv;
push(@rv, "[$_[0]->{'name'}]") if ($_[0]->{'name'});
foreach $k (keys %{$_[0]->{'values'}}) {
	push(@rv, $k."=".$_[0]->{'values'}->{$k});
	}
return @rv;
}

# apply_configuration()
# Apply the inetd and/or xinetd configuration
sub apply_configuration
{
if ($has_inetd) {
	local %iconfig = &foreign_config("inetd");
	&system_logged("$iconfig{'restart_command'} >/dev/null 2>&1 </dev/null");
	}
if ($has_xinetd) {
	local %xconfig = &foreign_config("xinetd");
	local $pid;
	if (open(PID, $xconfig{'pid_file'})) {
		chop($pid = <PID>);
		close(PID);
		kill('USR2', $pid);
		}
	}
return undef;
}

1;

