#!/usr/local/bin/perl
# sshd-lib.pl
# Common functions for the ssh daemon config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# Get version information
if (!&read_file("$module_config_directory/version", \%version)) {
	%version = &get_sshd_version();
	}

# get_sshd_version()
# Returns a hash containing the version type, number and full version
sub get_sshd_version
{
local %version;
local $out = &backquote_command(
	&quote_path($config{'sshd_path'})." -h 2>&1 </dev/null");
if ($config{'sshd_version'}) {
	# Forced version
	$version{'type'} = 'openssh';
	$version{'number'} = $version{'full'} = $config{'sshd_version'};
	}
elsif ($out =~ /(sshd\s+version\s+([0-9\.]+))/i ||
    $out =~ /(ssh\s+secure\s+shell\s+([0-9\.]+))/i) {
	# Classic commercial SSH
	$version{'type'} = 'ssh';
	$version{'number'} = $2;
	$version{'full'} = $1;
	}
elsif ($out =~ /(OpenSSH.([0-9\.]+))/i) {
	# OpenSSH .. assume all versions are supported
	$version{'type'} = 'openssh';
	$version{'number'} = $2;
	$version{'full'} = $1;
	}
elsif ($out =~ /(Sun_SSH_([0-9\.]+))/i) {
	# Solaris 9 SSH is actually OpenSSH 2.x
	$version{'type'} = 'openssh';
	$version{'number'} = 2.0;
	$version{'full'} = $1;
	}
elsif (($out = $config{'sshd_version'}) && ($out =~ /(Sun_SSH_([0-9\.]+))/i)) {
	# Probably Solaris 10 SSHD that didn't display version.  Use it.
	$version{'type'} = 'openssh';
	$version{'number'} = 2.0;
	$version{'full'} = $1;
	}
return %version;
}

# get_sshd_config()
# Returns a reference to an array of SSHD config file options
sub get_sshd_config
{
local @rv = ( { 'dummy' => 1,
		'indent' => 0,
		'file' => $config{'sshd_config'},
		'line' => -1,
		'eline' => -1 } );
local $lnum = 0;
open(CONF, "<".$config{'sshd_config'});
while(<CONF>) {
	s/\r|\n//g;
	s/^\s*#.*$//g;
	local ($name, @values) = split(/\s+/, $_);
	if ($name) {
		local $dir = { 'name' => $name,
			       'values' => \@values,
			       'file' => $config{'sshd_config'},
			       'line' => $lnum };
		push(@rv, $dir);
		}
	$lnum++;
	}
close(CONF);
return \@rv;
}

# find_value(name, &config)
sub find_value
{
foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0])) {
		return wantarray ? @{$c->{'values'}} : $c->{'values'}->[0];
		}
	}
return wantarray ? ( ) : undef;
}

# find(value, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0])) {
		push(@rv, $c);
		}
	}
return wantarray ? @rv : $rv[0];
}

# save_directive(name, &config, [value*|&values], [before])
sub save_directive
{
local @o = &find($_[0], $_[1]);
local @n = ref($_[2]) ?
		grep { defined($_) } @{$_[2]} :
		grep { defined($_) } @_[2..@_-1];
local $lref = &read_file_lines($_[1]->[0]->{'file'});
local $id = ("\t" x $_[1]->[0]->{'indent'});
local $i;
local $before = $_[3] && ref($_[2]) ? &find($_[3], $_[1]) : undef;
for($i=0; $i<@o || $i<@n; $i++) {
	if (defined($o[$i]) && defined($n[$i])) {
		# Replacing a line
		$lref->[$o[$i]->{'line'}] = "$id$_[0] $n[$i]";
		}
	elsif (defined($o[$i])) {
		# Removing a line
		splice(@$lref, $o[$i]->{'line'}, 1);
		foreach $c (@{$_[1]}) {
			if ($c->{'line'} > $o[$i]->{'line'}) {
				$c->{'line'}--;
				}
			}
		}
	elsif (defined($n[$i]) && !$before) {
		# Adding a line at the end, but before the first Match directive
		local $ll = $_[1]->[@{$_[1]}-1]->{'line'};
		foreach my $m (&find("Match", $_[1])) {
			$ll = $m->{'line'} - 1;
			last;
			}
		splice(@$lref, $ll+1, 0, "$id$_[0] $n[$i]");
		}
	elsif (defined($n[$i]) && $before) {
		# Adding a line before the first instance of some directive
		splice(@$lref, $before->{'line'}, 0, "$id$_[0] $n[$i]");
		foreach $c (@{$_[1]}) {
			if ($c->{'line'} >= $before->{'line'}) {
				$c->{'line'}--;
				}
			}
		}
	}
}

# save_socket(ports, listens)
sub save_socket
{
my ($ports, $listens) = @_;
return if ($version{'number'} < 6.7);
return if (!&foreign_available('init'));
&foreign_require('init');
my $default_port = 22;
my $socket_unit = &get_ssh_socket();
return if (!$socket_unit);

# Extend listens with IPs from default socket configuration if set
my $socket_details = &init::cat_systemd($socket_unit, 'ListenStream');
my ($socket_conf_file, $socket_conf_dir);
my @default_streams;
foreach my $entry (@$socket_details) {
	next if ($entry->{'file'} =~ m{^/run}); # Skip runtime files
	my $streams = $entry->{'sections'}{'Socket'}{'ListenStream'};
	if ($entry->{'file'} =~ m{^/etc}) {
		if (defined($streams)) {
			# Determine the socket configuration file and
			# directory from the custom config that defines
			# ListenStream to support multiple socket
			# override files (edge case)
			($socket_conf_dir, $socket_conf_file) =
				$entry->{'file'} =~ m|^(.*/)([^/]+)$|;
			$socket_conf_dir =~ s|/$|| if ($socket_conf_dir);
			}
		next;
		}
	if ($streams) {
		foreach my $stream (@$streams) {
			if ($stream =~ /^(?:\[(.+?)\]|([^:]+)):\d+$/) {
				my $address = defined($1) ? "[$1]" : $2;
				push(@default_streams, $address)
				}
			}
		}
	}

my @result;

# Set default port if empty
$ports = [$default_port] if (!@$ports);

# Check if port is different from default
my $port = @$ports == 1 && $ports->[0] == $default_port;

if (@$listens) {
	# Process listens
	foreach my $listen (@$listens) {
		if ($listen =~ /:\d+$/) {
			# If listen already contains a port, keep it as is
			push(@result, $listen);
			}
		elsif ($listen =~ /^\[.*\]$/) {
			# IPv6 address without a port
			push(@result, map { "$listen:$_" } @$ports);
			}
		else {
			# IPv4 address or hostname without a port
			push(@result, map { "$listen:$_" } @$ports);
			}
		}
	}

# Add ports not already in @result
if (!$port || @result) {
	foreach my $port (@$ports) {
		unless (grep { /:$port$/ } @result) {
			if (@default_streams) {
				push(@result, map { "$_:$port" }
					@default_streams);
				}
			else {
				push(@result, $port);
				}
			}
		}
	}

# Update socket if @results not empty
my $socket_conf = { 'Socket' => {} };
if (@result) {
	unshift(@result, '');
	$socket_conf = {
		'Socket' => {
			'ListenStream' => \@result,
			},
		};
	}
&init::edit_systemd($socket_unit, $socket_conf,
	$socket_conf_file, $socket_conf_dir);
}

# scmd(double)
sub scmd
{
if ($cmd_count % 2 == 0) {
	print "<tr>\n";
	}
elsif ($_[0]) {
	print "<td colspan=2></td> </tr>\n";
	print "<tr>\n";
	$cmd_count = 0;
	}
$cmd_count += ($_[0] ? 2 : 1);
}

# ecmd()
sub ecmd
{
if ($cmd_count % 2 == 0) {
	print "</tr>\n";
	}
}

# get_client_config()
# Returns a list of structures, one for each host
sub get_client_config
{
local @rv = ( { 'dummy' => 1,
		'indent' => 0,
		'file' => $config{'client_config'},
		'line' => -1,
		'eline' => -1 } );
local $host;
local $lnum = 0;
open(CLIENT, "<".$config{'client_config'});
while(<CLIENT>) {
	s/\r|\n//g;
	s/^\s*#.*$//g;
	s/^\s*//g;
	local ($name, @values) = split(/\s+/, $_);
	if (lc($name) eq 'host') {
		# Start of new host
		$host = { 'name' => $name,
			  'values' => \@values,
			  'file' => $config{'client_config'},
			  'line' => $lnum,
			  'eline' => $lnum,
			  'members' => [ { 'dummy' => 1,
					   'indent' => 1,
					   'file' => $config{'client_config'},
					   'line' => $lnum } ] };
		push(@rv, $host);
		}
	elsif ($name) {
		# A directive inside a host
		local $dir = { 'name' => $name,
			       'values' => \@values,
			       'file' => $config{'client_config'},
			       'line' => $lnum };
		push(@{$host->{'members'}}, $dir);
		$host->{'eline'} = $lnum;
		}
	$lnum++;
	}
close(CLIENT);
return \@rv;
}

# create_host(&host)
sub create_host
{
local $lref = &read_file_lines($config{'client_config'});
$_[0]->{'line'} = $_[0]->{'eline'} = scalar(@$lref);
push(@$lref, "Host ".join(" ", @{$_[0]->{'values'}}));
$_[0]->{'members'} = [ { 'dummy' => 1,
			 'indent' => 1,
			 'file' => $config{'client_config'},
			 'line' => $_[0]->{'line'} } ];
}

# modify_host(&host)
sub modify_host
{
local $lref = &read_file_lines($config{'client_config'});
$lref->[$_[0]->{'line'}] = "Host ".join(" ", @{$_[0]->{'values'}});
}

# delete_host(&host)
sub delete_host
{
local $lref = &read_file_lines($config{'client_config'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
}

# get_ssh_socket()
sub get_ssh_socket
{
return undef if ($version{'number'} < 6.7); 
return undef if (!&foreign_available('init'));
&foreign_require('init');
return undef if ($init::init_mode ne 'systemd');
my @socket_units = ('ssh.socket', 'sshd.socket');
my $socket_unit;
foreach (@socket_units) {
	if (&init::action_status($_) == 2) {
		$socket_unit = $_;
		last;
		}
	}
return $socket_unit if ($socket_unit);
return undef;
}

# restart_sshd()
# Re-starts the SSH server, and returns an error message on failure or
# undef on success
sub restart_sshd
{
if (my $ssh_socket = &get_ssh_socket()) {
	&init::restart_action($ssh_socket);
	}
elsif ($config{'restart_cmd'}) {
	local $out = `$config{'restart_cmd'} 2>&1 </dev/null`;
	return "<pre>$out</pre>" if ($?);
	}
else {
	local $pid = &get_sshd_pid();
	$pid || return $text{'apply_epid'};
	&kill_logged('HUP', $pid);
	}
return undef;
}

# stop_sshd()
# Kills the SSH server, and returns an error message on failure or
# undef on success
sub stop_sshd
{
if (my $ssh_socket = &get_ssh_socket()) {
	&init::stop_action($ssh_socket);
	}
elsif ($config{'stop_cmd'}) {
	local $out = `$config{'stop_cmd'} 2>&1 </dev/null`;
	return "<pre>$out</pre>" if ($?);
	}
else {
	local $pid = &get_sshd_pid();
	$pid || return $text{'apply_epid'};
	&kill_logged('TERM', $pid);
	}
return undef;
}

# start_sshd()
# Attempts to start the SSH server, returning undef on success or an error
# message on failure.
sub start_sshd
{
# Remove PID file if invalid
if (-f $config{'pid_file'} && !&check_pid_file($config{'pid_file'})) {
	&unlink_file($config{'pid_file'});
	}
if (my $ssh_socket = &get_ssh_socket()) {
	&init::start_action($ssh_socket);
	}
elsif ($config{'start_cmd'}) {
	$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
	if ($?) { return "<pre>$out</pre>"; }
	}
else {
	$out = &backquote_logged("$config{'sshd_path'} 2>&1 </dev/null");
	if ($?) { return "<pre>$out</pre>"; }
	}
return undef;
}

# get_pid_file()
# Returns the SSH server PID file
sub get_pid_file
{
local $conf = &get_sshd_config();
local $pidfile = &find_value("PidFile", $conf);
$pidfile ||= $config{'pid_file'};
return $pidfile;
}

# get_sshd_pid()
# Returns the PID of the running SSHd process
sub get_sshd_pid
{
local $file = &get_pid_file();
if ($file) {
	return &check_pid_file($file);
	}
else {
	local ($rv) = &find_byname("sshd");
	return $rv;
	}
}

# get_mlvalues(file, id, [splitchar])
# Return an array with values from a file, where the
# values are one per line with an id preceding them
sub get_mlvalues
{
local @rv;
local $_;
local $split = defined($_[2]) ? $_[2] : " ";
local $realfile = &translate_filename($_[0]);
&open_readfile(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	chomp;
	local $hash = index($_, "#");
	local $eq = index($_, $split);
	if ($hash != 0 && $eq >= 0) {
		local $n = substr($_, 0, $eq);
		local $v = substr($_, $eq+1);
		chomp($v);
		if ($n eq $_[1]) {
			push(@rv, $v);
						}
        	}
        }
close(ARFILE);
return @rv;
}

# list_syslog_facilities()
# Returns an upper-case list of syslog facility names
sub list_syslog_facilities
{
local @facils;
if (&foreign_check("syslog")) {
	local %sconfig = &foreign_config("syslog");
	@facils = map { uc($_) } split(/\s+/, $sconfig{'facilities'});
	}
if (!@facils) {
	@facils = ( 'DAEMON', 'USER', 'AUTH', 'AUTHPRIV', 'LOCAL0', 'LOCAL1', 'LOCAL2',
		    'LOCAL3', 'LOCAL4', 'LOCAL5', 'LOCAL6', 'LOCAL7' );
	}
return @facils;
}

sub list_logging_levels
{
return ('QUIET', 'FATAL', 'ERROR', 'INFO', 'VERBOSE', 'DEBUG');
}

sub yes_no_default_radio
{
local ($name, $val) = @_;
return &ui_radio($name, (lc($val) eq 'yes' || $val =~ /^\d+$/ && $val > 0) ? 1 :
			(lc($val) eq 'no' || $val =~ /^\d+$/) ? 0 : 2,
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ],
		   [ 2, $text{'default'} ] ]);
}

sub get_preferred_key_type
{
if ($version{'type'} eq 'openssh' && $version{'number'} >= 6.5) {
	return "ed25519";
	}
if ($version{'type'} eq 'openssh' && $version{'number'} >= 3.2) {
	return "rsa1";
	}
return undef;
}

1;

