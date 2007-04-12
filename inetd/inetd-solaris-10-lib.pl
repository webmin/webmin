# list_services()
# Returns a list of services from the services file, each being an array of
#  line name port protocol aliases index
sub list_services
{
local(@rv, $l);
$l = 0;
system("$config{'get_services_command'}") if ($config{'get_services_command'});
open(SERVICES, $config{services_file});
while(<SERVICES>) {
	chop; s/#.*$//g;
	if (/^(\S+)\s+([0-9]+)\/(\S+)\s*(.*)$/) {
		push(@rv, [ $l, $1, $2, $3, $4, scalar(@rv) ]);
		if ($config{'ipv6'}) {
			push(@rv, [ $l, $1, $2, $3.'6', $4, scalar(@rv) ]);
			# add udp/tcp6only options for s10
			if (($3 eq "tcp") | ($3 eq "udp")) {
				push(@rv, [ $l, $1, $2, $3.'6only',
					$4, scalar(@rv) ]);
				}
			}
		}
	$l++;
	}
close(SERVICES);
return @rv;
}

# create_service(name, port, proto, aliases)
# Add a new service to the list
sub create_service
{
local $p = $_[2];
if ($config{'ipv6'} && $p =~ /^(\S+)6.*$/) {
	# don't add the service if it is already there
	foreach $s (&list_services()) {
		return if ($s->[1] eq $_[0] && $s->[2] == $_[1] &&
			$s->[3] eq $1);
		}
	$p =~ s/6.*$//;
	}
&open_tempfile(SERVICES, ">> $config{services_file}");
&print_tempfile(SERVICES, "$_[0]\t$_[1]/$p",$_[3] ? "\t$_[3]\n" : "\n");
&close_tempfile(SERVICES);
system("$config{'put_services_command'}") if ($config{'put_services_command'});
}


# modify_service(line, name, port, proto, aliases)
# Change an existing service
sub modify_service
{
local(@serv, $p);
$p = $_[3];
$p =~ s/6.*$//;
open(SERVICES, $config{services_file});
@serv = <SERVICES>;
close(SERVICES);
$serv[$_[0]] = "$_[1]\t$_[2]/$p".($_[4] ? "\t$_[4]\n" : "\n");
&open_tempfile(SERVICES, "> $config{services_file}");
&print_tempfile(SERVICES, @serv);
&close_tempfile(SERVICES);
system("$config{'put_services_command'}") if ($config{'put_services_command'});
}

# delete_service(line)
sub delete_service
{
local(@serv);
open(SERVICES, $config{services_file});
@serv = <SERVICES>;
close(SERVICES);
splice(@serv, $_[0], 1);
&open_tempfile(SERVICES, "> $config{services_file}");
&print_tempfile(SERVICES, @serv);
&close_tempfile(SERVICES);
system("$config{'put_services_command'}") if ($config{'put_services_command'});
}

# list_protocols()
# Returns a list of supported protocols on this system
sub list_protocols
{
local(@rv);
open(PROT, $config{protocols_file});
while(<PROT>) {
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	/^(\S+)\s+/;
	push(@rv, $1);
	if ($config{'ipv6'}) {
		if ($1 eq 'tcp') { push(@rv, 'tcp6', 'tcp6only'); }
		elsif ($1 eq 'udp') { push(@rv, 'udp6', 'udp6only'); }
		}
	}
close(PROT);
return &unique(@rv);
}

# list_inets()
# Returns a list of service details handled by inetd. RPC services
# will have a name like foo/1 or bar/1-3, where the thing after the / is
# the version or versions supported. For each service, the list contains
#  line active? rpc? name type protocol wait user path|internal args file
sub list_inets
{
local ($cmd, @inetadm_output, $l, $fmri, $state, @rv);
# for smf, we need to build a list of service instances/states
# using inetadm, then gather relevant properties of each instance
$cmd = "/usr/sbin/inetadm";
@inetadm_output = &backquote_logged($cmd);
for ($l = 1; $l < scalar @inetadm_output; $l++) {
	# retrieve fmri, state from inetadm output
	$inetadm_output[$l] =~ /(\S+)\s+(\S+)\s+(\S+)/;
	$fmri = $3;
	$state = ($2 eq "online");
	# get instance props for fmri
	$cmd = "/usr/sbin/inetadm -l $fmri";
	$instance_props = &backquote_logged($cmd);
	$instance_props=~/(isrpc=)(\w+)/;
	$isrpc = ($2 eq "TRUE");
	if ($isrpc) {
		# for rpc svc, we need version range to
		# append to name
		$rpc = "rpc\/";
		$instance_props=~/(rpc_low_version=)(\w+)/;
		$rpc_lo = $2;
		$instance_props=~/(rpc_high_version=)(\w+)/;
		$rpc_hi = $2;
		if ($rpc_hi eq $rpc_lo) {
			$rpc_range = "\/$rpc_lo";
		} else {
			$rpc_range = "\/$rpc_lo-$rpc_hi";
		}
	} else {
		$rpc = "";
		$rpc_range = "";
	}
	$instance_props=~/(name=\")([^\"]*)/;
	$name = "$2$rpc_range";
	$instance_props=~/(endpoint_type=\")([^\"]*)/;
	$endpoint_type = $2;
	$instance_props=~/(proto=\")([^\"]*)/;
	$proto = "$rpc$2";
	$instance_props=~/(wait=)(\w+)/;
	$wait = ($2 eq "TRUE") ? "wait" : "nowait";
	$instance_props=~/(user=\")([^\"]*)/;
	$user = $2;
	$instance_props=~/(exec=\")([^\"]*)/;
	$exec = $2;
	# split exec into path to command, and command with args
	$exec =~/(\S+)[\s]*(.*)/;
	$cmdpath = $1;
	$args = $2;
	@cmdfields = split(/\//,$cmdpath);
	$cmd = "$cmdfields[-1] $args";
	push(@rv, [ $l, $state , $isrpc, $name, $endpoint_type, $proto,
	    $wait, $user, $exec, $cmd, $fmri]); 
	}
return @rv;
}

# create_inet(enabled, name, type, protocol, wait, user, program, args)
# Add a new service to the main inetd config file
sub create_inet
{
local ($proto, $name, $cmd, $retcode, $inetadm_output, $fmri);
# we need an ugly hack to support v6only protocols. inetconv won't
# accept v6only so we convert to v6, then inetadm -m proto=v6only.
$name = $_[1];
$proto = $_[3];
if ($_[3] =~ /.*6only/) {
	$proto =~ s/6.*$/6/;
	}
&open_tempfile(INET, ">$config{inetd_conf_file}");
&print_tempfile(INET, "$_[1]\t$_[2]\t$proto\t$_[4]\t$_[5]\t$_[6]". 
	   ($_[7] ? "\t$_[7]\n" : "\n"));
&close_tempfile(INET);
$name =~ s/\//_/;
$proto =~ s/\//_/;
$retcode = &execute_smf_cmd("/usr/sbin/inetconv -i $config{inetd_conf_file}");
if ($retcode) { return undef; }
# we need to determine fmri of just-created svc...
$inetadm_output = &backquote_logged("/usr/sbin/inetadm");
if ($inetadm_output =~ /(.*)(svc\:\/(.)*\/$name\/$proto:default)(.*)/) {
	$fmri = $2;
	if ($_[3] =~ /.*6only/) {
		# now change proto to correct v6only value. from inetconv
		# operation we know fmri will be of form "svcname/proto"
		$retcode =
		    &execute_smf_cmd("/usr/sbin/inetadm -m $fmri proto=$_[3]");
		if ($retcode) { return undef; }
		}
	if (!$_[0]) {
		# disable svc
		$retcode = &execute_smf_cmd("/usr/sbin/inetadm -d $fmri");
		}
	}
return undef;
}


# modify_inet(line, enabled, name, type, protocol,
#	      wait, user, program, args, fmri)
# Modify an existing inetd service
sub modify_inet
{
local ($fmri, $wait, $protocol, $isrpc, $name, $rpc_lo,
	$rpc_hi, $rpc_mods, $cmd, $args, @cmdfields, @argfields,
	$firstarg, $argstr, $start_method, $retcode);
$fmri = $_[9];
$name = $_[2];
$wait = ($_[5] eq "wait") ? "TRUE" : "FALSE";
$protocol = $_[4];
$cmd = $_[7];
$args = $_[8];
# for smf, cmd name must match first arg
@cmdfields = split(/\//, $cmd);
@argfields = split(/\s+/, $args);
$firstarg = shift(@argfields);
if ($firstarg eq $cmdfields[-1]) {
	$argstr = join(" ", @argfields);
	$start_method = "$cmd $argstr";
} else {
	&error(&text('error_smf_cmdfield', $cmd, $cmdfields[-1]));
	return undef;
}
if ($name =~ /(^[^\/]*)\/([1-9]*)[\-]*([1-9]*)$/) {
	$rpc_lo = $2;
	$rpc_hi = $3;
	$name = $1;
	if (!$rpc_hi) { $rpc_hi = $rpc_lo; }
	$isrpc = 1;
	$protocol =~ s/^(rpc\/)*//;
	$rpc_mods = "rpc_low_version=$rpc_lo rpc_high_version=$rpc_hi";
} else {
	$rpc_mods = "";
	}
$retcode = &execute_smf_cmd("/usr/sbin/inetadm -m $fmri name=$name endpoint_type=$_[3] proto=$protocol wait=$wait user=$_[6] exec=$start_method $rpc_mods");
if ($retcode) { return undef; }
if ($_[1]) {
	# may need to clear maintenance state
	&backquote_logged("/usr/sbin/svcadm clear $fmri");
	$retcode = &execute_smf_cmd("/usr/sbin/inetadm -e $fmri");
} else {
	$retcode = &execute_smf_cmd("/usr/sbin/inetadm -d $fmri");
	}
return undef;
}


# delete_inet(line, fmri)
# Delete an internet service
sub delete_inet
{
local ($fmri, @fields, $svc, $retcode, $out);
$fmri = $_[1];
# before we delete, check if this is only instance for service.
# if so we svccfg delete the whole service, otherwise just the
# instance. this is to avoid leaving unwanted detritus lying
# around in the smf repository...
@fields = split(/:/,$fmri);
$svc = "svc:/$fields[1]";
$out = &backquote_logged("/usr/sbin/inetadm | /usr/bin/grep $svc | wc -l");
if ($?) { return undef; }
if ($out =~ /\s*1\s*/) {
	# XXX need to remove manifest too?
	&webmin_log("running svccfg delete on $svc");
	$fmri = $svc;
	}
$retcode = &execute_smf_cmd("/usr/sbin/svccfg delete -f $fmri");
return undef;
}

sub execute_smf_cmd
{
local ($cmd, $out, $retcode);
$cmd = $_[0];
$out = &backquote_logged($cmd);
$retcode = $?;
if ($retcode) {
	&error(&text('error_smfservice', $cmd, $retcode));
	}
return $retcode;
}

%prot_name = ("ip", "Internet Protocol",
              "tcp", "Transmission Control Protocol",
              "udp", "User Datagram Protocol",
              "tcp6", "Transmission Control Protocol IPv6",
              "tcp6only", "Transmission Control Protocol IPv6 only, no v4",
              "udp6", "User Datagram Protocol IPv6",
              "udp6only", "User Datagram Protocol IPv6 only, no v4");

