# Functions for editing the Open-iSCSI configuration file

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
&foreign_require("fdisk");
&foreign_require("mount");
&foreign_require("lvm");
our (%text, %config, %gconfig, $module_config_file);

# check_config()
# Returns undef if the Open-iSCSI client is installed, or an error message if
# missing
sub check_config
{
return &text('check_econfig', "<tt>$config{'config_file'}</tt>")
	if (!-r $config{'config_file'});
return &text('check_eisciadm', "<tt>$config{'iscsiadm'}</tt>")
	if (!&has_command($config{'iscsiadm'}));
return undef;
}

# get_iscsi_config()
# Parses the iscsi client config file into an array ref of directives
sub get_iscsi_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'config_file'}) || return [ ];
while(<$fh>) {
        s/\r|\n//g;
        s/#.*$//;
	if (/^(\S+)\s*=\s*(.*)/) {
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum };
		push(@rv, $dir);
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# find(&config, name)
# Returns all config objects with the given name
sub find
{
my ($conf, $name) = @_;
my @t = grep { $_->{'name'} eq $name } @$conf;
return wantarray ? @t : $t[0];
}

# find_value(&config, name)
# Returns all config values with the given name
sub find_value
{
my ($conf, $name) = @_;
my @rv = map { $_->{'value'} } &find($conf, $name);
return wantarray ? @rv : $rv[0];
}

# save_directive(&config, name, value)
# Creates, updates or deletes some directive
sub save_directive
{
my ($conf, $name, $value) = @_;
my $lref = &read_file_lines($config{'config_file'});
my $line = defined($value) ? $name." = ".$value : undef;
my $o = &find($conf, $name);
if ($o && defined($value)) {
	# Update a line
	$lref->[$o->{'line'}] = $line;
	$o->{'value'} = $value;
	}
elsif ($o && !defined($value)) {
	# Commenting out a line
	$lref->[$o->{'line'}] = "# ".$lref->[$o->{'line'}];
	}
elsif (!$o && defined($value)) {
	# Check if exists, but commented out
	my $cline;
	my $clnum = 0;
	foreach my $l (@$lref) {
		if ($l =~ /^#+\s*\Q$name\E\s*=/) {
			$cline = $clnum;
			last;
			}
		$clnum++;
		}
	my $dir = { 'name' => $name,
		    'value' => $value };
	if (defined($cline)) {
		# Comment back in
		$dir->{'line'} = $cline;
		$lref->[$cline] = $line;
		}
	else {
		# Add at end
		$dir->{'line'} = scalar(@$lref);
		push(@$lref, $line);
		}
	push(@$conf, $dir);
	}
}

# list_iscsi_connections()
# Returns a list of hash refs with details of active sessions
sub list_iscsi_connections
{
my @rv;
&clean_language();
my $out = &backquote_command(
		"$config{'iscsiadm'} -m session -o show -P 3 -S 2>/dev/null");
&reset_environment();
my @lines = split(/\r?\n/, $out);
if ($?/256 == 21) {
	# Code 21 means no sessions
	return [ ];
	}
if ($?) {
	return $lines[0];
	}
my $conn;
foreach my $l (@lines) {
	if ($l =~ /^Target:\s+(\S+):(\S+)/) {
		$conn = { 'name' => $1,
			  'target' => $2 };
		push(@rv, $conn);
		}
	elsif ($l =~ /Current\s+Portal:\s+(\S+):(\d+)/) {
		$conn->{'ip'} = $1;
		$conn->{'port'} = $2;
		}
	elsif ($l =~ /SID:\s+(\d+)/) {
		$conn->{'num'} = $1;
		}
	elsif ($l =~ /Iface\s+Name:\s+(\S+)/) {
		$conn->{'iface'} = $1;
		}
	elsif ($l =~ /Iface\s+Transport:\s+(\S+)/) {
		$conn->{'proto'} = $1;
		}
	elsif ($l =~ /Iface\s+Initiatorname:\s+(\S+)/) {
		$conn->{'initiator'} = $1;
		}
	elsif ($l =~ /iSCSI\s+Connection\s+State:\s+(\S+)/) {
		$conn->{'connection'} = $1;
		}
	elsif ($l =~ /iSCSI\s+Session\s+State:\s+(\S+)/) {
		$conn->{'session'} = $1;
		}
	elsif ($l =~ /scsi(\d+)\s+Channel\s+(\d+)\s+Id\s+(\d+)\s+Lun:\s+(\d+)/) {
		$conn->{'scsihost'} = $1;
		$conn->{'scsichannel'} = $2;
		$conn->{'scsiid'} = $3;
		$conn->{'scsilun'} = $4;
		}
	elsif ($l =~ /Attached\s+scsi\s+disk\s+(\S+)/) {
		$conn->{'device'} = "/dev/$1";
		}
	elsif ($l =~ /(username|password|username_in|password_in):\s+(\S+)/ &&
	       $2 ne "<empty>") {
		$conn->{$1} = $2;
		}
	}
foreach my $c (@rv) {
	my $dev = "/dev/disk/by-path/ip-$c->{'ip'}:$c->{'port'}-".
		  "iscsi-$c->{'name'}:$c->{'target'}-lun-$c->{'scsilun'}";
	if (-e $dev) {
		$c->{'longdevice'} = $dev;
		}
	}
return \@rv;
}

# list_iscsi_targets(host, [port], [iface])
# Returns an array ref listing available targets on some host, or an error 
# message string
sub list_iscsi_targets
{
my ($host, $port, $iface) = @_;
my $cmd = "$config{'iscsiadm'} -m discovery -t sendtargets -p ".
	  quotemeta($host).($port ? ":".quotemeta($port) : "").
	  ($iface ? " -I ".quotemeta($iface) : "");
&clean_language();
my $out = &backquote_command("$cmd 2>&1");
&reset_environment();
my @lines = split(/\r?\n/, $out);
if ($? || $out =~ /Could not perform SendTargets discovery/i) {
	return $lines[0];
	}
my @rv;
foreach my $l (@lines) {
	if ($l =~ /^(\S+):(\d+),(\d+)\s+(\S+):(\S+)/) {
		push(@rv, { 'ip' => $1,
			    'port' => $2,
			    'name' => $4,
			    'target' => $5 });
		}
	}
return \@rv;
}

# create_iscsi_connection(host, [port], [iface], &target,
# 			  [method, username, password])
# Attempts to connect to an iscsi server for the given target (or all targets)
sub create_iscsi_connection
{
my ($host, $port, $iface, $target, $method, $user, $pass) = @_;

# Re-discover targets, so that this function works when called remotely
&list_iscsi_targets($host, $port, $iface);

my $cmd = "$config{'iscsiadm'} -m node".
	  ($target ? " -T ".quotemeta($target->{'name'}).":".
			    quotemeta($target->{'target'}) : "").
	  " -p ".quotemeta($host).($port ? ":".quotemeta($port) : "").
	  ($iface ? " -I ".quotemeta($iface) : "");

# Create the session
&clean_language();
my $out = &backquote_logged("$cmd 2>&1");
&reset_environment();
return $out if ($?);

# Set session username and password
if ($method) {
	&clean_language();
	my $out = &backquote_logged("$cmd --op=update --name=node.session.auth.authmethod --value=$method 2>&1");
	&reset_environment();
	return $out if ($?);
	}
if ($user) {
	&clean_language();
	my $out = &backquote_logged("$cmd --op=update --name=node.session.auth.username --value=".quotemeta($user)." 2>&1");
	&reset_environment();
	return $out if ($?);

	&clean_language();
	$out = &backquote_logged("$cmd --op=update --name=node.session.auth.password --value=".quotemeta($pass)." 2>&1");
	&reset_environment();
	return $out if ($?);
	}

# Connect the session with --login
&clean_language();
$out = &backquote_logged("$cmd --login 2>&1");
&reset_environment();
return $out if ($?);

return undef;
}

# delete_iscsi_connection(&connection)
# Remove an existing connection to some target
sub delete_iscsi_connection
{
my ($conn) = @_;
my $cmd = "$config{'iscsiadm'} -m node".
	  " -T ".quotemeta($conn->{'name'}).":".quotemeta($conn->{'target'}).
	  " -p ".quotemeta($conn->{'ip'}).":".quotemeta($conn->{'port'}).
	  " --logout";
&clean_language();
my $out = &backquote_logged("$cmd 2>&1");
&reset_environment();
return $? ? $out : undef;
}

# get_connection_users(&conn, [include-unused])
# Returns a list of partitions in the device for some connection, and their
# users (like raid, mount, lvm)
sub get_connection_users
{
my ($conn, $unused) = @_;
return ( ) if (!$conn->{'device'});
my @users;
my @disks = &fdisk::list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $conn->{'device'} } @disks;
next if (!$disk);
foreach my $part (@{$disk->{'parts'}}) {
	my @st = &fdisk::device_status($part->{'device'});
	if (@st || $unused) {
		push(@users, [ $conn, $part, @st ]);
		}
	}
return @users;
}

# get_initiator_name()
# Returns the local iSCSI initiator name
sub get_initiator_name
{
my $data = &read_file_contents($config{'initiator_file'});
return $data =~ /InitiatorName=(\S+)/ ? $1 : undef;
}

# save_initiator_name(name)
# Writes out the initiator name file
sub save_initiator_name
{
my ($name) = @_;
my $fh = "INIT";
&open_tempfile($fh, ">$config{'initiator_file'}");
&print_tempfile($fh, "InitiatorName=$name\n");
&close_tempfile($fh);
}

# generate_initiator_name()
# Create a new initiator name with the iscsi-iname command
sub generate_initiator_name
{
my $out = &backquote_command("$config{'iscsiiname'} 2>/dev/null");
$out =~ s/\r?\n//;
return $out;
}

# list_iscsi_ifaces()
# Returns an array ref of details of all existing interfaces
sub list_iscsi_ifaces
{
&clean_language();
my $errtemp = &transname();
my $out = &backquote_command(
		"$config{'iscsiadm'} -m iface -o show -P 1 2>$errtemp");
&reset_environment();
my @lines = split(/\r?\n/, $out);
my $err = &read_file_contents($errtemp);
if ($?) {
	return "Interfaces are not supported by this OpenISCSI version"
		if ($err =~ /Invalid\s+info\s+level/);
	return $err || $lines[0];
	}
my @rv;
my ($iface, $target);
foreach my $l (@lines) {
	if ($l =~ /^Iface:\s+(\S+)/) {
		$iface = { 'name' => $1,
			   'builtin' => ($1 eq "default" || $1 eq "iser"),
			   'targets' => [ ] };
		push(@rv, $iface);
		}
	elsif ($l =~ /Target:\s+(\S+):(\S+)/) {
		$target = { 'name' => $1,
			    'target' => $2 };
		push(@{$iface->{'targets'}}, $target);
		}
	elsif ($l =~ /Portal:\s+(\S+):(\d+)/) {
		$target->{'ip'} = $1;
		$target->{'port'} = $2;
		}
	}
# Fetch more info for each interface
foreach my $iface (@rv) {
	&clean_language();
	my $out = &backquote_command(
		"$config{'iscsiadm'} -m iface -I $iface->{'name'} 2>/dev/null");
	&reset_environment();
	foreach my $il (split(/\r?\n/, $out)) {
		if ($il !~ /^#/ && $il =~ /^(iface.\S+)\s*=\s*(\S+)/) {
			$iface->{$1} = $2 eq "<empty>" ? undef : $2;
			}
		}
	}
return \@rv;
}

# create_iscsi_interface(&iface)
# Create a new interface from the given hash
sub create_iscsi_interface
{
my ($iface) = @_;

# Create the initial interface
my $cmd = "$config{'iscsiadm'} -m iface -o new".
	  " -I ".quotemeta($iface->{'name'});
&clean_language();
my $out = &backquote_logged("$cmd 2>&1");
&reset_environment();
return $out if ($?);

# Apply various params
foreach my $k (grep { /^iface\./ } keys %$iface) {
	my $cmd = "$config{'iscsiadm'} -m iface -o update".
          " -I ".quotemeta($iface->{'name'}).
	  " -n ".quotemeta($k)." -v ".quotemeta($iface->{$k});
	&clean_language();
	my $out = &backquote_logged("$cmd 2>&1");
	&reset_environment();
	return "Failed to set $k : $out" if ($?);
	}

return undef;
}

# delete_iscsi_iface(&iface)
# Delete one iSCSI interface
sub delete_iscsi_iface
{
my ($iface) = @_;
my $cmd = "$config{'iscsiadm'} -m iface -o delete".
	  " -I ".quotemeta($iface->{'name'});
&clean_language();
my $out = &backquote_logged("$cmd 2>&1");
&reset_environment();
return $? ? $out : undef;
}

1;
