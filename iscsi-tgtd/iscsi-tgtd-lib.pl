# iscsi-tgtd-lib.pl
# Common functions for managing and configuring the iSCSI TGTD server

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
     $list_logical_volumes_cache, $get_tgtd_config_cache);

# check_config()
# Returns undef if the iSCSI server is installed, or an error message if
# missing
sub check_config
{
return $text{'check_econfigset'} if (!$config{'config_file'});
return &text('check_econfig', "<tt>$config{'config_file'}</tt>")
	if (!-r $config{'config_file'});
return &text('check_etgtadm', "<tt>$config{'tgtadm'}</tt>")
	if (!&has_command($config{'tgtadm'}));
#&foreign_require("init");
#return &text('check_einit', "<tt>$config{'init_name'}</tt>")
#	if (&init::action_status($config{'init_name'}) == 0);
return undef;
}

# get_tgtd_config()
# Parses the iSCSI server config file in an array ref of objects
sub get_tgtd_config
{
if (!$get_tgtd_config_cache) {
	$get_tgtd_config_cache = &read_tgtd_config_file($config{'config_file'});
	}
return $get_tgtd_config_cache;
}

# read_tgtd_config_file(file)
# Parses a single config file into an array ref
sub read_tgtd_config_file
{
my ($file) = @_;
my @rv;
my $lnum = 0;
my $parent;
my $lref = &read_file_lines($file, 1);
my @pstack;
foreach my $ol (@$lref) {
	my $l = $ol;
	$l =~ s/#.*$//;
	if ($l =~ /^\s*include\s(\S+)/) {
		# Include some other files
		my $ifile = $1;
		foreach my $iglob (glob($ifile)) {
			next if (!-r $iglob);
			my $inc = &read_tgtd_config_file($iglob);
			push(@rv, @$inc);
			}
		}
	elsif ($l =~ /^\s*<(\S+)\s+(.*)>/) {
		# Start of a block
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'values' => [ split(/\s+/, $2) ],
			    'type' => 1,
			    'members' => [ ],
			    'file' => $file,
			    'line' => $lnum,
			    'eline' => $lnum };
		if ($parent) {
			push(@{$parent->{'members'}}, $dir);
			}
		else {
			push(@rv, $dir);
			}
		push(@pstack, $parent);
		$parent = $dir;
		}
	elsif ($l =~ /^\s*<\/(\S+)>/) {
		# End of a block
		$parent->{'eline'} = $lnum;
		$parent = pop(@pstack);
		}
	elsif ($l =~ /^\s*(\S+)\s+(\S.*)/) {
		# Some directive in a block
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'values' => [ split(/\s+/, $2) ],
			    'type' => 0,
			    'file' => $file,
			    'line' => $lnum,
			    'eline' => $lnum };
		if ($parent) {
			push(@{$parent->{'members'}}, $dir);
			}
		else {
			push(@rv, $dir);
			}
		}
	$lnum++;
	}
return \@rv;
}

# save_directive(&config, [&old|old-name], [&new], [&parent], [add-file-file])
# Replaces, creates or deletes some directive
sub save_directive
{
my ($conf, $olddir, $newdir, $parent, $addfile) = @_;
my $file;
if ($olddir && !ref($olddir)) {
	# Lookup the old directive by name
	$olddir = &find($parent ? $parent->{'members'} : $conf, $olddir);
	}
if ($olddir) {
	# Modifying old directive's file
	$file = $olddir->{'file'};
	}
elsif ($addfile) {
	# Adding to a specific file
	$file = $addfile;
	}
elsif ($parent) {
	# Adding to parent's file
	$file = $parent->{'file'};
	}
else {
	# Adding to the default config file
	$file = $config{'config_file'};
	}
my $lref = $file ? &read_file_lines($file) : undef;
my @lines = $newdir ? &directive_lines($newdir) : ( );
my $oldlen = $olddir ? $olddir->{'eline'} - $olddir->{'line'} + 1 : undef;
my $oldidx = $olddir && $parent ? &indexof($olddir, @{$parent->{'members'}}) :
	     $olddir ? &indexof($olddir, @$conf) : undef;
my ($renumline, $renumoffset);
if ($olddir && $newdir) {
	# Replace some directive
	if ($lref) {
		splice(@$lref, $olddir->{'line'}, $oldlen, @lines);
		$newdir->{'file'} = $olddir->{'file'};
		$newdir->{'line'} = $olddir->{'line'};
		$newdir->{'eline'} = $newdir->{'line'} + scalar(@lines) - 1;
		if ($parent) {
			$parent->{'eline'} += scalar(@lines) - $oldlen;
			}
		}
	if ($parent) {
		$parent->{'members'}->[$oldidx] = $newdir;
		}
	else {
		$conf->[$oldidx] = $newdir;
		}
	$renumline = $newdir->{'eline'};
	$renumoffset = scalar(@lines) - $oldlen;
	}
elsif ($olddir) {
	# Remove some directive
	if ($lref) {
		splice(@$lref, $olddir->{'line'}, $oldlen);
		}
	if ($parent) {
		# From inside parent
		splice(@{$parent->{'members'}}, $oldidx, 1);
		if ($lref) {
			$parent->{'eline'} -= $oldlen;
			}
		}
	else {
		# From top-level
		splice(@$conf, $oldidx, 1);
		}
	$renumline = $olddir->{'line'};
	$renumoffset = $oldlen;
	}
elsif ($newdir) {
	# Add some directive
	if ($lref) {
		$newdir->{'file'} = $file;
		}
	if ($parent) {
		# Inside parent
		if ($lref) {
			$newdir->{'line'} = $parent->{'eline'};
			$newdir->{'eline'} = $newdir->{'line'} +
					     scalar(@lines) - 1;
			$parent->{'eline'} += scalar(@lines);
			splice(@$lref, $newdir->{'line'}, 0, @lines);
			}
		$parent->{'members'} ||= [ ];
		$parent->{'type'} ||= 1;
		push(@{$parent->{'members'}}, $newdir);
		}
	else {
		# At end of file
		if ($lref) {
			$newdir->{'line'} = scalar(@lines);
			$newdir->{'eline'} = $newdir->{'line'} +
					     scalar(@lines) - 1;
			push(@$lref, @lines);
			}
		push(@$conf, $newdir);
		}
	$renumline = $newdir->{'eline'};
	$renumoffset = scalar(@lines);
	}

# Apply any renumbering to the config (recursively)
if ($renumoffset && $lref) {
	&recursive_renumber($conf, $file, $renumline, $renumoffset,
			    [ $newdir, $parent ? ( $parent ) : ( ) ]);
	}
}

# save_multiple_directives(&config, name, &directives, &parent)
# Update all existing directives with some name
sub save_multiple_directives
{
my ($conf, $name, $newdirs, $parent) = @_;
my $olddirs = [ &find($parent ? $parent->{'members'} : $conf, $name) ];
for(my $i=0; $i<@$olddirs || $i<@$newdirs; $i++) {
	&save_directive($conf,
			$i<@$olddirs ? $olddirs->[$i] : undef,
			$i<@$newdirs ? $newdirs->[$i] : undef,
			$parent);
	}
}

# delete_if_empty(file)
# Remove some file if after modification it contains no non-whitespace lines
sub delete_if_empty
{
my ($file) = @_;
my $lref = &read_file_lines($file, 1);
foreach my $l (@$lref) {
	return 0 if ($l =~ /\S/);
	}
&unlink_file($file);
&unflush_file_lines($file);
return 1;
}

# recursive_renumber(&directives, file, after-line, offset, &ignore-list)
sub recursive_renumber
{
my ($conf, $file, $renumline, $renumoffset, $ignore) = @_;
foreach my $c (@$conf) {
	if ($c->{'file'} eq $file && &indexof($c, @$ignore) < 0) {
		$c->{'line'} += $renumoffset if ($c->{'line'} > $renumline);
		$c->{'eline'} += $renumoffset if ($c->{'eline'} > $renumline);
		}
	if ($c->{'type'}) {
		&recursive_renumber($c->{'members'}, $file, $renumline,
				    $renumoffset, $ignore);
		}
	}
}

# directive_lines(&dir, [indent])
# Returns the lines of text for some directive
sub directive_lines
{
my ($dir, $indent) = @_;
$indent ||= 0;
my $istr = " " x $indent;
my @rv;
if ($dir->{'type'}) {
	# Has sub-directives
	push(@rv, $istr."<".$dir->{'name'}.
		  ($dir->{'value'} ? " ".$dir->{'value'} : "").">");
	foreach my $s (@{$dir->{'members'}}) {
		push(@rv, &directive_lines($s, $indent+1));
		}
	push(@rv, $istr."</".$dir->{'name'}.">");
	}
else {
	# Just a name/value
	push(@rv, $istr.$dir->{'name'}.
		  ($dir->{'value'} ? " ".$dir->{'value'} : ""));
	}
return @rv;
}

# find(&config|&object, name)
# Returns all config objects with the given name
sub find
{
my ($conf, $name) = @_;
$conf = $conf->{'members'} if (ref($conf) eq 'HASH');
my @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# find_value(&config|&object, name)
# Returns config values with the given name
sub find_value
{
my ($conf, $name) = @_;
$conf = $conf->{'members'} if (ref($conf) eq 'HASH');
my @rv = map { $_->{'value'} } &find($conf, $name);
return wantarray ? @rv : $rv[0];
}

# is_tgtd_running()
# Returns the PID if the server process is running, or 0 if not
sub is_tgtd_running
{
my $pid = &find_byname("tgtd");
return $pid;
}

# setup_tgtd_init()
# If no init script exists, create one
sub setup_tgtd_init
{
&foreign_require("init");
return 0 if (&init::action_status($config{'init_name'}));
&init::enable_at_boot($config{'init_name'},
		      "Start TGTd iSCSI server",
		      &has_command($config{'tgtd'}).
		        " && sleep 2 && ".
			&has_command($config{'tgtadmin'})." -e",
		      "killall -9 tgtd",
		      undef,
		      { 'fork' => 1 },
		      );
}

# start_iscsi_tgtd()
# Run the init script to start the server
sub start_iscsi_tgtd
{
if ($config{'start_cmd'}) {
	my $out = &backquote_command("$config{'start_cmd'} 2>&1 </dev/null");
	return $? ? $out : undef;
	}
else {
	&setup_tgtd_init();
	&foreign_require("init");
	my ($ok, $out) = &init::start_action($config{'init_name'});
	return $ok ? undef : $out;
	}
}

# stop_iscsi_tgtd()
# Run the init script to stop the server
sub stop_iscsi_tgtd
{
if ($config{'stop_cmd'}) {
	my $out = &backquote_command("$config{'stop_cmd'} 2>&1 </dev/null");
	return $? ? $out : undef;
	}
else {
	&setup_tgtd_init();
	&foreign_require("init");
	my ($ok, $out) = &init::stop_action($config{'init_name'});
	return $ok ? undef : $out;
	}
}

# restart_iscsi_tgtd()
# Sends a HUP signal to re-read the configuration
sub restart_iscsi_tgtd
{
if ($config{'restart_cmd'}) {
	my $out = &backquote_command("$config{'restart_cmd'} 2>&1 </dev/null");
	return $? ? $out : undef;
	}
else {
	&stop_iscsi_tgtd();
	# Wait for process to exit
	for(my $i=0; $i<20; $i++) {
		last if (!&is_tgtd_running());
		sleep(1);
		}
	return &start_iscsi_tgtd();
	}
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

# find_host_name(&config)
# Returns the first host name part of the first target
sub find_host_name
{
my ($conf) = @_;
my %hcount;
foreach my $t (&find_value($conf, "target")) {
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

1;
