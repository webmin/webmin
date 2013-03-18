# iscsi-server-lib.pl
# Common functions for managing and configuring an iSCSI server

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
&foreign_require("raid");
&foreign_require("fdisk");
&foreign_require("lvm");
&foreign_require("mount");
our (%text, %config, %gconfig, $module_config_file);

# check_config()
# Returns undef if the iSCSI server is installed, or an error message if
# missing
sub check_config
{
return &text('check_etargets', "<tt>$config{'targets_file'}</tt>")
	if (!-r $config{'targets_file'});
return &text('check_eserver', "<tt>$config{'iscsi_server'}</tt>")
	if (!&has_command($config{'iscsi_server'}));
return undef;
}

# get_iscsi_config()
# Returns an array ref of entries from the iSCSI server config file
sub get_iscsi_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'targets_file'}) || return [ ];
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	my @w = split(/\s+/, $_);
	if (@w && $w[0] =~ /^extent(\d+)/) {
		# An extent is a sub-section of some file or device
		my $ext = { 'type' => 'extent',
			    'num' => $1,
			    'line' => $lnum,
			    'device' => $w[1],
			    'start' => &parse_bytes($w[2]),
			    'size' => &parse_bytes($w[3]),
			   };
		push(@rv, $ext);
		}
	elsif (@w && $w[0] =~ /^device(\d+)/) {
		# A device is a collection of extents
		my $dev = { 'type' => 'device',
			    'num' => $1,
			    'line' => $lnum,
			    'mode' => $w[1],
			    'extents' => [ @w[2..$#w] ],
			  };
		push(@rv, $dev);
		}
	elsif (@w && $w[0] =~ /^target(\d+)/) {
		# A target is the export of an extent
		if (@w == 3) {
			# If flags are missing, assume read/write
			@w = ( $w[0], "ro", $w[1], $w[2] );
			}
		my $tar = { 'type' => 'target',
			    'num' => $1,
			    'line' => $lnum,
			    'flags' => $w[1],
                            'export' => $w[2],
			    'network' => $w[3] };
		push(@rv, $tar);
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# find(&config, type, [number])
# Returns all config objects with the given type and optional number
sub find
{
my ($conf, $type, $num) = @_;
my @t = grep { $_->{'type'} eq $type } @$conf;
if (defined($num)) {
	@t = grep { $_->{'num'} eq $num } @t;
	}
return wantarray ? @t : $t[0];
}

# save_directive(&config, &old, &new)
# Creates, updates or deletes some directive
sub save_directive
{
my ($conf, $o, $n) = @_;
my $lref = &read_file_lines($config{'targets_file'});
my $line = $n ? &make_directive_line($n) : undef;
if ($o && $n) {
	# Update a line
	$lref->[$o->{'line'}] = $line;
	}
elsif ($o && !$n) {
	# Remove a line
	splice(@$lref, $o->{'line'}, 1);
	foreach my $c (@$conf) {
		if ($c->{'line'} > $o->{'line'}) {
			$c->{'line'}--;
			}
		}
	my $idx = &indexof($o, @$conf);
	if ($idx >= 0) {
		splice(@$conf, $idx, 1);
		}
	}
elsif (!$o && $n) {
	# Add a line. Extents should come before any devices, and devices 
	# before any targets
	my @allsame = &find($conf, $n->{'type'});
	my $lastsame = @allsame ? pop(@allsame) : undef;
	my $addline = scalar(@$lref);
	if ($lastsame) {
		# Add after last of the same type
		$addline = $lastsame->{'line'}+1;
		}
	elsif ($n->{'type'} eq 'device') {
		# Add before any targets
		my $firsttarget = &find($conf, "target");
		$addline = $firsttarget->{'line'} if ($addline);
		}
	elsif ($n->{'type'} eq 'extent') {
		# Add before any devices
		my $firstdevice = &find($conf, "device");
		$addline = $firstdevice->{'line'} if ($addline);
		}
	$n->{'line'} = $addline;
	splice(@$lref, $addline, 0, $line);
	foreach my $c (@$conf) {
		if ($c->{'line'} >= $addline) {
			$c->{'line'}++;
			}
		}
	push(@$conf, $n);
	}
&flush_file_lines($config{'targets_file'});
}

# make_directive_line(&dir)
# Returns the line of text for some directive
sub make_directive_line
{
my ($dir) = @_;
my @rv;
if ($dir->{'type'} eq 'extent') {
	@rv = ( $dir->{'type'}.$dir->{'num'},
		$dir->{'device'},
		&convert_bytes($dir->{'start'}),
		&convert_bytes($dir->{'size'}) );
	}
elsif ($dir->{'type'} eq 'device') {
	@rv = ( $dir->{'type'}.$dir->{'num'},
		$dir->{'mode'},
		@{$dir->{'extents'}} );
	}
elsif ($dir->{'type'} eq 'target') {
	@rv = ( $dir->{'type'}.$dir->{'num'},
		$dir->{'flags'},
		$dir->{'export'},
		$dir->{'network'} );
	}
return join(" ", @rv);
}

# parse_bytes(str)
# Converts a string like 100MB into a number of bytes
sub parse_bytes
{
my ($str) = @_;
if ($str =~ /^(\d+)TB/i) {
	return $1 * 1024 * 1024 * 1024 * 1024;
	}
elsif ($str =~ /^(\d+)GB/i) {
	return $1 * 1024 * 1024 * 1024;
	}
elsif ($str =~ /^(\d+)MB/i) {
	return $1 * 1024 * 1024;
	}
elsif ($str =~ /^(\d+)KB/i) {
	return $1 * 1024;
	}
elsif ($str =~ /^\d+$/) {
	return $str;
	}
else {
	&error("Unknown size number $str");
	}
}

# convert_bytes(num)
# Converts a number into a smaller number with a suffix like MB or GB
sub convert_bytes
{
my ($n) = @_;
if ($n == 0) {
	return $n;
	}
elsif ($n % (1024*1024*1024*1024) == 0) {
	return ($n / (1024*1024*1024*1024))."TB";
	}
elsif ($n % (1024*1024*1024) == 0) {
	return ($n / (1024*1024*1024))."GB";
	}
elsif ($n % (1024*1024) == 0) {
	return ($n / (1024*1024))."MB";
	}
elsif ($n % (1024) == 0) {
	return ($n / (1024))."KB";
	}
else {
	return $n;
	}
}

# is_iscsi_server_running()
# Returns the PID if the server process is running, or 0 if not
sub is_iscsi_server_running
{
return &check_pid_file($config{'pid_file'});
}

# start_iscsi_server()
# Launch the iscsi server process, and return undef if successful
sub start_iscsi_server
{
my $str = &get_iscsi_options_string();
my $out = &backquote_logged("$config{'iscsi_server'} -f $config{'targets_file'} $str 2>&1 </dev/null");
return $? ? $out : undef;
}

# stop_iscsi_server()
# Kill the running iscsi server process
sub stop_iscsi_server
{
my $pid = &is_iscsi_server_running();
return "Not running" if (!$pid);
return kill('TERM', $pid) ? undef : "Kill failed : $!";
}

# restart_iscsi_server()
# Kill and re-start the iscsi server process
sub restart_iscsi_server
{
&stop_iscsi_server();
return &start_iscsi_server();
}

# find_free_num(&config, type)
# Returns the max used device number of some type, plus 1
sub find_free_num
{
my ($conf, $type) = @_;
my $max = -1;
foreach my $c (&find($conf, $type)) {
	if ($c->{'num'} > $max) {
		$max = $c->{'num'};
		}
	}
return $max + 1;
}

# get_device_size(device, "part"|"raid"|"lvm"|"other")
# Returns the size in bytes of some device, which can be a partition, RAID
# device, logical volume or regular file. For devices, removes 1 MB as this
# seems to be needed for overhead or rounding or something.
sub get_device_size
{
my ($dev, $type) = @_;
if ($type eq "part") {
	# A partition or whole disk
	foreach my $d (&fdisk::list_disks_partitions()) {
		if ($d->{'device'} eq $dev) {
			# Whole disk
			return $d->{'cylinders'} * $d->{'cylsize'};
			}
		foreach my $p (@{$d->{'parts'}}) {
			if ($p->{'device'} eq $dev) {
				return ($p->{'end'} - $p->{'start'} + 1) *
				       $d->{'cylsize'} - (1024 * 1024);
				}
			}
		}
	return undef;
	}
elsif ($type eq "raid") {
	# A RAID device
	my $conf = &raid::get_raidtab();
	foreach my $c (@$conf) {
		if ($c->{'value'} eq $dev) {
			return ($c->{'size'} * 1024) - (1024 * 1024);
			} 
		}
	return undef;
	}
elsif ($type eq "lvm") {
	# LVM volume group
	foreach my $v (&lvm::list_volume_groups()) {
		foreach my $l (&lvm::list_logical_volumes($v->{'name'})) {
			if ($l->{'device'} eq $dev) {
				return ($l->{'size'} * 1024) - (1024 * 1024);
				}
			}
		}
	}
else {
	# A regular file
	my @st = stat($dev);
	return @st ? $st[7] : undef;
	}
}

# find_extent_users(&config, &extent|&device)
# Returns a list of all targets or devices using some extent or device
sub find_extent_users
{
my ($conf, $obj) = @_;
my $name = $obj->{'type'}.$obj->{'num'};
my @rv;
foreach my $c (@$conf) {
	if ($c->{'type'} eq 'target' && $c->{'export'} eq $name) {
		push(@rv, $c);
		}
	elsif ($c->{'type'} eq 'device' &&
	       &indexof($name, @{$c->{'extents'}}) >= 0) {
		push(@rv, $c);
		}
	}
return @rv;
}

# describe_object(&object)
# Returns a human-readable description of some extent, device or target
sub describe_object
{
my ($obj) = @_;
if ($obj->{'type'} eq 'extent') {
	return &text('desc_extent', &mount::device_name($obj->{'device'}));
	}
elsif ($obj->{'type'} eq 'device') {
	return &text('desc_device', "<tt>$obj->{'type'}$obj->{'num'}</tt>");
	}
elsif ($obj->{'type'} eq 'target') {
	return &text('desc_target', $obj->{'network'});
	}
else {
	return "Unknown $obj->{'type'} object";
	}
}

# expand_extents(&config, &seen, name, ...)
# Returns the recursively expanded list of sub-devices of the listed devices
sub expand_extents
{
my ($conf, $seen, @names) = @_;
my @rv;
foreach my $n (@names) {
	push(@rv, $n);
	if ($n =~ /^device(\d+)$/) {
		my $d = &find($conf, "device", $1);
		if ($d && !$seen->{$n}++) {
			push(@rv, &expand_extents($conf, $seen,
						  @{$d->{'extents'}}));
			}
		}
	}
return @rv;
}

# get_iscsi_options_file()
# Returns the file containing command-line options, for use when locking
sub get_iscsi_options_file
{
if ($gconfig{'os_type'} eq 'freebsd') {
	my %iconfig = &foreign_config("init");
	my @rcdirs = split(/\s+/, $iconfig{'rc_dir'});
	foreach my $d (@rcdirs) {
		my $file = $d."/".$config{'init_name'}.".sh";
		return $file if (-r $file);
		$file = $d."/".$config{'init_name'};
		return $file if (-r $file);
		}
	return $rcdirs[$#rcdirs]."/".$config{'init_name'}.".sh";
	}
else {
	return $config{'opts_file'};
	}
}

# get_iscsi_options_string()
# Returns all flags as a string
sub get_iscsi_options_string
{
my $file = &get_iscsi_options_file();
if ($gconfig{'os_type'} eq 'freebsd') {
	# Stored in FreeBSD rc script, in command_args line
	my $lref = &read_file_lines($file, 1);
	foreach my $l (@$lref) {
		if ($l =~ /^\s*command_args\s*=\s*"(.*)"/) {
			return $1;
			}
		}
	}
else {
	# Stored in an environment variables file
	my %env;
	&read_env_file($file, \%env);
	return $env{'NETBSD_ISCSI_OPTS'};
	}
}

# get_iscsi_options()
# Returns a hash ref of command line options
sub get_iscsi_options
{
my $str = &get_iscsi_options_string();
my %opts;
while($str =~ /\S/) {
	if ($str =~ /^\s*\-(b|f|p|m|t|v)\s+(\S+)(.*)/) {
		$str = $3;
		$opts{$1} = $2;
		}
	elsif ($str =~ /^\s*\-((4|6|D|V)+)(.*)/) {
		$str = $3;
		foreach my $o (split(//, $1)) {
			$opts{$o} = "";
			}
		}
	else {
		&error("Unknown option $str");
		}
	}
return \%opts;
}

# save_iscsi_options_string(str)
# Update the options file with command line options from a string
sub save_iscsi_options_string
{
my ($str) = @_;
my $file = &get_iscsi_options_file();
if ($gconfig{'os_type'} eq 'freebsd') {
	my $lref = &read_file_lines($file);
	foreach my $l (@$lref) {
		if ($l =~ /^\s*command_args\s*=\s*"(.*)"/) {
			$l = "command_args=\"$str\"";
			}
		}
	&flush_file_lines($file);
	}
else {
	my %env;
	&read_env_file($file, \%env);
	$env{'NETBSD_ISCSI_OPTS'} = $str;
	&write_env_file($file, \%env);
	}
}

# save_iscsi_options(&opts)
# Update the options file with command line options from a hash
sub save_iscsi_options
{
my ($opts) = @_;
my @str;
foreach my $o (keys %$opts) {
	if ($opts->{$o} eq "") {
		push(@str, "-".$o);
		}
	else {
		push(@str, "-".$o." ".$opts->{$o});
		}
	}
&save_iscsi_options_string(join(" ", @str));
}

# list_iscsi_users()
# Parses the auths file and returns an array of users
sub list_iscsi_users
{
my @rv;
my $fh = "AUTHS";
my $lnum = 0;
&open_readfile($fh, $config{'auths_file'}) || return ( );
while(<$fh>) {
	s/\r|\n//;
	s/\s+$//;
	s/#.*$//;
	my ($user, $mode, $pass, @rest) = split(/:/, $_);
	if ($user) {
		my $uinfo = { 'user' => $user,
			      'mode' => $mode,
			      'pass' => $pass,
			      'rest' => \@rest,
			      'line' => $lnum };
		push(@rv, $uinfo);
		}
	$lnum++;
	}
close($fh);
return @rv;
}

# create_iscsi_user(&user)
# Add a new iSCSI user
sub create_iscsi_user
{
my ($user) = @_;
my $fh = "AUTHS";
&open_tempfile($fh, ">>$config{'auths_file'}", 0, 1);
&print_tempfile($fh, join(":", $user->{'user'},
			       $user->{'mode'},
			       $user->{'pass'})."\n");
&close_tempfile($fh);
}

# modify_iscsi_user(&user)
# Update an existing user
sub modify_iscsi_user
{
my ($user) = @_;
my $lref = &read_file_lines($config{'auths_file'});
$lref->[$user->{'line'}] = join(":", $user->{'user'},
				     $user->{'mode'},
				     $user->{'pass'})."\n";
&flush_file_lines($config{'auths_file'});
}

# delete_iscsi_user(&user)
# Remove one user
sub delete_iscsi_user
{
my ($user) = @_;
my $lref = &read_file_lines($config{'auths_file'});
splice(@$lref, $user->{'line'}, 1);
&flush_file_lines($config{'auths_file'});
}

1;

