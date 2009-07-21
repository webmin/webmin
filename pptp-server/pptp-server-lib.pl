# pptp-server-lib.pl
# Common functions for PPTP server configuration
# XXX help pages

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'secrets-lib.pl';
%access = &get_module_acl();

$options_pptp = $config{'pptp_ppp_options'} || "/etc/ppp/options.pptp";

# get_config()
# Returns the PPTP configuration
sub get_config
{
local @rv;
local $lnum = 0;
open(FILE, $config{'file'});
while(<FILE>) {
	s/\r|\n//g;
	if (/^\s*(#?)\s*(\S+)\s*(\S*)\s*$/) {
		push(@rv, { 'name' => $2,
			    'value' => $3,
			    'enabled' => !$1,
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(FILE);
return \@rv;
}

# find_conf(name, &config)
sub find_conf
{
local $c;
foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0]) && $c->{'enabled'}) {
		return $c->{'value'};
		}
	}
return undef;
}

# save_directive(&config, name, [value])
sub save_directive
{
local $lref = &read_file_lines($config{'file'});
local ($old) = grep { lc($_->{'name'}) eq lc($_[1]) } @{$_[0]};
if ($old) {
	if (defined($_[2])) {
		# Can just update old one
		$lref->[$old->{'line'}] = "$_[1]\t$_[2]";
		}
	elsif ($old->{'enabled'}) {
		# Comment out old one
		$lref->[$old->{'line'}] = "#$old->{'name'}\t$old->{'value'}";
		}
	}
elsif (defined($_[2])) {
	# Add to end of file
	push(@$lref, "$_[1]\t$_[2]");
	}
}

# get_pptpd_pid()
# Returns the PID of the running PPTP server process
sub get_pptpd_pid
{
open(PID, $config{'pid_file'}) || return undef;
local $pid = <PID>;
$pid = int($pid);
close(PID);
return $pid;
}

# get_ppp_hostname()
# Returns the hostname that this server uses for authentication
sub get_ppp_hostname
{
local $conf = &get_config();
local $option = &find_conf("option", $conf);
$option ||= $config{'ppp_options'};
local @opts = &parse_ppp_options($option);
local $name = &find("name", \@opts);
return $name ? $name->{'value'} : &get_system_hostname(1);
}

# parse_ppp_options(file)
sub parse_ppp_options
{
local @rv;
local $lnum = 0;
open(OPTS, $_[0]);
while(<OPTS>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/^([0-9\.]+):([0-9\.]+)/) {
		push(@rv, { 'local' => $1,
			    'remote' => $2,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	elsif (/^(\S+)\s*(.*)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(OPTS);
return @rv;
}

# find(name, &config)
sub find
{
local @rv = grep { lc($_->{'name'}) eq lc($_[0]) } @{$_[1]};
return wantarray ? @rv : $rv[0];
}

# save_ppp_option(&config, file, &old|name, &new)
sub save_ppp_option
{
local $ol = ref($_[2]) || !defined($_[2]) ? $_[2] : &find($_[2], $_[0]);
local $nw = $_[3];
local $lref = &read_file_lines($_[1]);
local $line;
if ($nw) {
	if ($nw->{'local'}) {
		$line = $nw->{'local'}.":".$nw->{'remote'};
		}
	else {
		$line = $nw->{'name'};
		$line .= " $nw->{'value'}" if ($nw->{'value'} ne "");
		}
	}
if ($ol && $nw) {
	$lref->[$ol->{'line'}] = $line;
	}
elsif ($ol) {
	splice(@$lref, $ol->{'line'}, 1);
	local $c;
	foreach $c (@{$_[0]}) {
		$c->{'line'}-- if ($c->{'line'} > $ol->{'line'});
		}
	}
elsif ($nw) {
	push(@$lref, $line);
	}
}

# list_connections()
# Returns a list of active PPTP connections by checking the process list.
# Each element of the list is an array containing the PPP PID, PPTP PID,
# client IP, interface, local IP and remote IP, start time and username
sub list_connections
{
local @rv;

# Look in the log file for connection messages
local (%pppuser, %localip, %remoteip);
&open_readfile(LOG, $config{'log_file'});
while(<LOG>) {
	if (/pppd\[(\d+)\].*authentication\s+succeeded\s+for\s+(\S+)/i) {
		$pppuser{$1} = $2;
		}
	elsif (/pppd\[(\d+)\].*local\s+IP\s+address\s+(\S+)/) {
		$localip{$1} = $2;
		}
	elsif (/pppd\[(\d+)\].*remote\s+IP\s+address\s+(\S+)/) {
		$remoteip{$1} = $2;
		}
	}
close(LOG);

# Check for running pptpd and pppd processes
&foreign_require("proc", "proc-lib.pl");
&foreign_require("net", "net-lib.pl");
local @procs = &proc::list_processes();
local @ifaces = &net::active_interfaces();
foreach $p (@procs) {
	if ($p->{'args'} =~ /pptpd\s*\[([0-9\.]+)/) {
		# Found a PPTP connection process .. get the child PPP proc
		local $rip = $1;
		local ($ppp) = grep { $_->{'ppid'} == $p->{'pid'} } @procs;
		local $user = $ppp ? $pppuser{$ppp->{'pid'}} : undef;
		local $lip;
		if ($ppp && ($lip=$localip{$ppp->{'pid'}})) {
			# We got the local and remote IPs from the log file
			local $rip2 = $remoteip{$ppp->{'pid'}};
			local ($iface) = grep { $_->{'address'} eq $lip &&
						$_->{'ptp'} eq $rip } @ifaces;
			push(@rv, [ $ppp->{'pid'}, $p->{'pid'},
				    $rip, $iface ? $iface->{'fullname'} : undef,
				    $lip, $rip2,
				    $ppp->{'_stime'}, $user ] );
			}
		elsif ($ppp && $ppp->{'args'} =~ /([0-9\.]+):([0-9\.]+)/) {
			# Find the matching interface
			local ($iface) = grep { $_->{'address'} eq $1 &&
						$_->{'ptp'} eq $2 } @ifaces;
			if ($iface) {
				push(@rv, [ $ppp->{'pid'}, $p->{'pid'},
					    $rip, $iface->{'fullname'},
					    $1, $iface->{'ptp'} || $2,
					    $ppp->{'_stime'}, $user ] );
				}
			else {
				push(@rv, [ $ppp->{'pid'}, $p->{'pid'},
					    $rip, undef, $1, $2,
					    $ppp->{'_stime'}, $user ] );
				}
			}
		elsif ($ppp) {
			# PPP process doesn't include IPs
			push(@rv, [ $ppp->{'pid'}, $p->{'pid'},
				    $rip, undef, undef, undef,
				    $ppp->{'_stime'}, $user ] );
			}
		}
	}
return @rv;
}

# get_pptpd_version(&out)
sub get_pptpd_version
{
local $out = `$config{'pptpd'} -v 2>&1`;
${$_[0]} = $out;
return $out =~ /(PoPToP|pptpd)\s+v?(\S+)/i ? $2 : undef;
}

# apply_configuration()
# Attempts to apply the PPTP server configuration, and returns undef on
# success or an error message on failure
sub apply_configuration
{
# Stop first
if ($config{'stop_cmd'}) {
	local $out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	return "<pre>$out</pre>" if ($?);
	}
else {
	local $pid = &get_pptpd_pid();
	if (!$pid || !&kill_logged('TERM', $pid)) {
		return $text{'stop_egone'};
		}
	}

# Re-start
local $cmd = $config{'start_cmd'} || $config{'pptpd'};
local $temp = &tempname();
local $rv = &system_logged("$cmd >$temp 2>&1 </dev/null");
local $out = `cat $temp`;
unlink($temp);
if ($rv) {
	return "<pre>$out</pre>";
	}
return undef;
}

1;

