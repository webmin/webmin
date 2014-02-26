# iscsi-target-lib.pl
# Common functions for managing and configuring an iSCSI target

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
our ($list_disks_partitions_cache, $get_raidtab_cache,
     $list_logical_volumes_cache);

# check_config()
# Returns undef if the iSCSI server is installed, or an error message if
# missing
sub check_config
{
return &text('check_econfig', "<tt>$config{'config_file'}</tt>")
	if (!-r $config{'config_file'});
return &text('check_eietadm', "<tt>$config{'ietadm'}</tt>")
	if (!&has_command($config{'ietadm'}));
&foreign_require("init");
return &text('check_einit', "<tt>$config{'init_name'}</tt>")
	if (&init::action_status($config{'init_name'}) == 0);
return undef;
}

# get_iscsi_config()
# Returns an array ref of entries from the iSCSI target config file
sub get_iscsi_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'config_file'}) || return [ ];
my $parent = undef;
while(<$fh>) {
        s/\r|\n//g;
        s/#.*$//;
        my @w = split(/\s+/, $_);
	shift(@w) if (@w && $w[0] eq '');	# Due to indentation
	my $dir;
	if (@w) {
		$dir = { 'name' => $w[0],
			 'value' => join(" ", @w[1..$#w]),
			 'values' => [ @w[1..$#w] ],
			 'line' => $lnum,
			 'eline' => $lnum };
		}
	if (/^\S/) {
		# Top-level directive
		$dir->{'indent'} = 0;
		$parent = $dir;
		push(@rv, $parent);
		}
	elsif (@w) {
		# Sub-directive
		$parent || &error("Sub-directive with no parent at line $lnum");
		$parent->{'members'} ||= [ ];
		push(@{$parent->{'members'}}, $dir);
		$dir->{'indent'} = 1;
		$parent->{'eline'} = $dir->{'line'};
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# get_iscsi_config_parent()
# Returns a fake object for the whole config
sub get_iscsi_config_parent
{
my $conf = &get_iscsi_config();
my $lref = &read_file_lines($config{'config_file'}, 1);
return { 'members' => $conf,
	 'indent' => -1,
	 'top' => 1,
	 'line' => 0,
	 'eline' => scalar(@$lref)-1 };
}

# save_directive(&config, &parent, name|&old-objects, value|&values)
# Updates some config entry
sub save_directive
{
my ($conf, $parent, $name_or_old, $values) = @_;
my $lref = &read_file_lines($config{'config_file'});

# Find old objects
my @o;
if (ref($name_or_old)) {
	@o = @{$name_or_old};
	}
else {
	@o = &find($parent->{'members'}, $name_or_old);
	}

# Construct new objects
$values = [ $values ] if (ref($values) ne 'ARRAY');
my @n = map { ref($_) ? $_ : { 'name' => $name_or_old,
			       'value' => $_ } } @$values;

# Find first target, to insert before
my ($first_target) = &find($parent->{'members'}, "Target");

for(my $i=0; $i<@n || $i<@o; $i++) {
	my $o = $i<@o ? $o[$i] : undef;
	my $n = $i<@n ? $n[$i] : undef;
	if ($o && $n) {
		# Update a directive
		if (defined($o->{'line'})) {
			$lref->[$o->{'line'}] = &make_directive_line(
							$n, $o->{'indent'});
			}
		$o->{'name'} = $n->{'name'};
		$o->{'value'} = $n->{'value'};
		}
	elsif (!$o && $n && $parent->{'top'} && $n->{'name'} ne 'Target' &&
	       $first_target) {
		# Add before first Target
		my @lines = &make_directive_lines($n,
                                        $parent->{'indent'} + 1);
		splice(@$lref, $first_target->{'line'}, 0, @lines);
		&renumber($conf, $first_target->{'line'} - 1, scalar(@lines));
		$n->{'line'} = $first_target->{'line'} - 1;
		$n->{'eline'} = $n->{'line'} + scalar(@lines) - 1;
		push(@{$parent->{'members'}}, $n);
		}
	elsif (!$o && $n) {
		# Add a directive at end of parent
		if (defined($parent->{'line'})) {
			my @lines = &make_directive_lines($n,
					$parent->{'indent'} + 1);
			&renumber($conf, $parent->{'eline'}, scalar(@lines));
			splice(@$lref, $parent->{'eline'} + 1, 0, @lines);
			$n->{'line'} = $parent->{'eline'} + 1;
			$n->{'eline'} = $n->{'line'} + scalar(@lines) - 1;
			$parent->{'eline'} = $n->{'eline'};
			}
		push(@{$parent->{'members'}}, $n);
		}
	elsif ($o && !$n) {
		# Remove a directive
		if (defined($o->{'line'})) {
			splice(@$lref, $o->{'line'},
			       $o->{'eline'} - $o->{'line'} + 1);
			&renumber($conf, $o->{'line'} - 1, 
				  -($o->{'eline'} - $o->{'line'} + 1));
			}
		my $idx = &indexof($o, @{$parent->{'members'}});
		if ($idx >= 0) {
			splice(@{$parent->{'members'}}, $idx, 1);
			}
		}
	}
}

# renumber(&config, line, offset)
# Moves directives after some line by the given offset
sub renumber
{
my ($conf, $line, $offset) = @_;
foreach my $c (@$conf) {
	$c->{'line'} += $offset if ($c->{'line'} > $line);
	$c->{'eline'} += $offset if ($c->{'eline'} > $line);
	if ($c->{'members'}) {
		&renumber($c->{'members'}, $line, $offset);
		}
	}
}

# make_directive_line(&directive, indent?)
# Returns the first line of a config object
sub make_directive_line
{
my ($dir, $indent) = @_;
return ($indent ? "\t" : "").$dir->{'name'}." ".$dir->{'value'};
}

# make_directive_lines(&directive, indent?)
# Returns the all lines of a config object
sub make_directive_lines
{
my ($dir, $indent) = @_;
my @rv = ( &make_directive_line($dir, $indent) );
if ($dir->{'members'}) {
	foreach my $m (@{$dir->{'members'}}) {
		push(@rv, &make_directive_line($m, $indent+1));
		}
	}
return @rv;
}

# find(&config, name)
# Returns all config objects with the given name
sub find
{
my ($conf, $name) = @_;
my @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# find_value(&config, name)
# Returns config values with the given name
sub find_value
{
my ($conf, $name) = @_;
my @rv = map { $_->{'value'} } &find($conf, $name);
return wantarray ? @rv : $rv[0];
}

# is_iscsi_target_running()
# Returns the PID if the server process is running, or 0 if not
sub is_iscsi_target_running
{
foreach my $pidfile (split(/\s+/, $config{'pid_file'})) {
	my $pid = &check_pid_file($pidfile);
	return $pid if ($pid);
	}
return undef;
}

# find_host_name(&config)
# Returns the first host name part of the first target
sub find_host_name
{
my ($conf) = @_;
my %hcount;
foreach my $t (&find_value($conf, "Target")) {
	my ($host) = split(/:/, $t);
	$hcount{$host}++;
	}
my @hosts = sort { $hcount{$b} <=> $hcount{$a} } (keys %hcount);
return $hosts[0];
}

# generate_host_name()
# Returns the first part of a target name, in the standard format
sub generate_host_name
{
my @tm = localtime(time());
return sprintf("iqn.%.4d-%.2d.%s", $tm[5]+1900, $tm[4]+1,
	       join(".", reverse(split(/\./, &get_system_hostname()))));
}

# start_iscsi_server()
# Run the init script to start the server
sub start_iscsi_server
{
&foreign_require("init");
my ($ok, $out) = &init::start_action($config{'init_name'});
return $ok ? undef : $out;
}

# stop_iscsi_server()
# Run the init script to stop the server
sub stop_iscsi_server
{
&foreign_require("init");
my ($ok, $out) = &init::stop_action($config{'init_name'});
return $ok ? undef : $out;
}

# restart_iscsi_server()
# Sends a HUP signal to re-read the configuration
sub restart_iscsi_server
{
&stop_iscsi_server();
# Wait for process to exit
for(my $i=0; $i<20; $i++) {
	last if (!&is_iscsi_target_running());
	sleep(1);
	}
return &start_iscsi_server();
}

# get_iscsi_options_file()
# Returns the file containing command-line options, for use when locking
sub get_iscsi_options_file
{
return $config{'opts_file'};
}

# get_iscsi_options_string()
# Returns all flags as a string
sub get_iscsi_options_string
{
my $file = &get_iscsi_options_file();
my %env;
&read_env_file($file, \%env);
return $env{'OPTIONS'};
}

# get_iscsi_options()
# Returns a hash ref of command line options
sub get_iscsi_options
{
my $str = &get_iscsi_options_string();
my %opts;
while($str =~ /\S/) {
	if ($str =~ /^\s*\-(c|d|g|a|p|u)\s+(\S+)(.*)/) {
		# Short arg, like -p 123
		$str = $3;
		$opts{$1} = $2;
		}
	elsif ($str =~ /^\s*\--(config|debug|address|port)=(\S+)(.*)/) {
		# Long arg, like --address=5.5.5.5
		$str = $3;
		$opts{$1} = $2;
		}
	elsif ($str =~ /^\s*\-((f)+)(.*)/) {
		# Arg with no value, like -f
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
my %env;
&read_env_file($file, \%env);
$env{'OPTIONS'} = $str;
&write_env_file($file, \%env);
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
	elsif (length($o) == 1) {
		push(@str, "-".$o." ".$opts->{$o});
		}
	else {
		push(@str, "--".$o."=".$opts->{$o});
		}
	}
&save_iscsi_options_string(join(" ", @str));
}

sub get_allow_file
{
my ($mode) = @_;
if ($mode eq "targets") {
	return $config{'targets_file'};
	}
elsif ($mode eq "initiators") {
	return $config{'initiators_file'};
	}
else {
	&error("Unknown allow file type $mode");
	}
}

# get_allow_config("targets"|"initiators")
# Parses a file listing allowed IPs into an array ref
sub get_allow_config
{
my ($mode) = @_;
my $file = &get_allow_file($mode);
my $fh = "CONFIG";
my $lnum = 0;
my @rv;
&open_readfile($fh, $file) || return [ ];
while(<$fh>) {
        s/\r|\n//g;
        s/#.*$//;
        my @w = split(/[ ,]+/, $_);
	if (@w) {
		push(@rv, { 'name' => $w[0],
			    'addrs' => [ @w[1..$#w] ],
			    'index' => scalar(@rv),
			    'mode' => $mode,
			    'file' => $file,
			    'line' => $lnum });
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# create_allow(&allow)
# Add some target or initiator allow to the appropriate file
sub create_allow
{
my ($a) = @_;
my $file = &get_allow_file($a->{'mode'});
my $lref = &read_file_lines($file);
push(@$lref, &make_allow_line($a));
&flush_file_lines($file);
}

# delete_allow(&delete)
# Delete some target or initiator allow from the appropriate file
sub delete_allow
{
my ($a) = @_;
my $file = &get_allow_file($a->{'mode'});
my $lref = &read_file_lines($file);
splice(@$lref, $a->{'line'}, 1);
&flush_file_lines($file);
}

# modify_allow(&delete)
# Update some target or initiator allow in the appropriate file
sub modify_allow
{
my ($a) = @_;
my $file = &get_allow_file($a->{'mode'});
my $lref = &read_file_lines($file);
$lref->[$a->{'line'}] = &make_allow_line($a);
&flush_file_lines($file);
}

# make_allow_line(&allow)
# Returns the line of text for an allow file entry
sub make_allow_line
{
my ($a) = @_;
return $a->{'name'}." ".join(", ", @{$a->{'addrs'}});
}

# get_device_size(device, "part"|"raid"|"lvm"|"other")
# Returns the size in bytes of some device, which can be a partition, RAID
# device, logical volume or regular file.
sub get_device_size
{
my ($dev, $type) = @_;
if (!$type) {
	$type = $dev =~ /^\/dev\/md\d+$/ ? "raid" :
		$dev =~ /^\/dev\/([^\/]+)\/([^\/]+)$/ ? "lvm" :
	        $dev =~ /^\/dev\/(s|h|v|xv)d[a-z]+\d*$/ ? "part" : "other";
	}
if ($type eq "part") {
	# A partition or whole disk
	foreach my $d (&list_disks_partitions_cached()) {
		if ($d->{'device'} eq $dev) {
			# Whole disk
			return $d->{'cylinders'} * $d->{'cylsize'};
			}
		foreach my $p (@{$d->{'parts'}}) {
			if ($p->{'device'} eq $dev) {
				return ($p->{'end'} - $p->{'start'} + 1) *
				       $d->{'cylsize'};
				}
			}
		}
	return undef;
	}
elsif ($type eq "raid") {
	# A RAID device
	my $conf = &get_raidtab_cached();
	foreach my $c (@$conf) {
		if ($c->{'value'} eq $dev) {
			return $c->{'size'} * 1024;
			} 
		}
	return undef;
	}
elsif ($type eq "lvm") {
	# LVM volume group
	foreach my $l (&list_logical_volumes_cached()) {
		if ($l->{'device'} eq $dev) {
			return $l->{'size'} * 1024;
			}
		}
	}
else {
	# A regular file
	my @st = stat($dev);
	return @st ? $st[7] : undef;
	}
}

sub list_disks_partitions_cached
{
$list_disks_partitions_cache ||= [ &fdisk::list_disks_partitions() ];
return @$list_disks_partitions_cache;
}

sub get_raidtab_cached
{
$get_raidtab_cache ||= &raid::get_raidtab();
return $get_raidtab_cache;
}

sub list_logical_volumes_cached
{
if (!$list_logical_volumes_cache) {
	$list_logical_volumes_cache = [ ];
	foreach my $v (&lvm::list_volume_groups()) {
		push(@$list_logical_volumes_cache,
		     &lvm::list_logical_volumes($v->{'name'}));
		}
	}
return @$list_logical_volumes_cache;
}

1;
