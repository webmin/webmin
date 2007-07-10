# raid-lib.pl
# Functions for managing RAID

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");

open(MODE, "$module_config_directory/mode");
chop($raid_mode = <MODE>);
close(MODE);

%container = ( 'raiddev', 1,
	       'device', 1 );

# get_mdstat()
# Read information about active RAID devices. Returns a hash indexed by
# device name (like /dev/md0), with each value being an array reference
# containing  status  level  disks  blocks  resync  disk-info
sub get_mdstat
{
# Read the mdstat file
local %mdstat;
local $lastdev;
open(MDSTAT, $config{'mdstat'});
while(<MDSTAT>) {
	if (/^(md\d+)\s*:\s+(\S+)\s+(\S+)\s+(.*)\s+(\d+)\s+blocks\s*(.*)resync=(\d+)/) {
		$mdstat{$lastdev = "/dev/$1"} = [ $2, $3, $4, $5, $7, $6 ];
		}
	elsif (/^(md\d+)\s*:\s+(\S+)\s+(\S+)\s+(.*)\s+(\d+)\s+blocks\s*(.*)/) {
		$mdstat{$lastdev = "/dev/$1"} = [ $2, $3, $4, $5, undef, $6 ];
		}
	elsif (/^(md\d+)\s*:\s+(\S+)\s+(\S+)\s+(.*)/) {
		$mdstat{$lastdev = "/dev/$1"} = [ $2, $3, $4 ];
		$_ = <MDSTAT>;
		if (/\s+(\d+)\s+blocks\s*(.*)resync=(\d+)/) {
			$mdstat{$lastdev}->[3] = $1;
			$mdstat{$lastdev}->[4] = $3;
			$mdstat{$lastdev}->[5] = $2;
			}
		elsif (/\s+(\d+)\s+blocks\s*(.*)/) {
			$mdstat{$lastdev}->[3] = $1;
			$mdstat{$lastdev}->[5] = $2;
			}
		}
	}
close(MDSTAT);
return %mdstat;
}

# get_raidtab()
# Parse the raid config file into a list of devices
sub get_raidtab
{
local ($raiddev, $device, %mdstat);
return \@get_raidtab_cache if (defined(@get_raidtab_cache));
%mdstat = &get_mdstat();

if ($raid_mode eq "raidtools") {
	# Read the raidtab file
	local $lnum = 0;
	open(RAID, $config{'raidtab'});
	while(<RAID>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^\s*(\S+)\s+(\S+)/) {
			local $dir = { 'name' => lc($1),
				       'value' => $2,
				       'line' => $lnum,
				       'eline' => $lnum };
			if ($dir->{'name'} =~ /^(raid|spare|parity|failed)-disk$/) {
				push(@{$device->{'members'}}, $dir);
				$device->{'eline'} = $lnum;
				$raiddev->{'eline'} = $lnum;
				}
			elsif ($dir->{'name'} eq 'raiddev') {
				$dir->{'index'} = scalar(@get_raidtab_cache);
				push(@get_raidtab_cache, $dir);
				}
			else {
				push(@{$raiddev->{'members'}}, $dir);
				$raiddev->{'eline'} = $lnum;
				}
			if ($dir->{'name'} eq 'device') {
				$device = $dir;
				}
			elsif ($dir->{'name'} eq 'raiddev') {
				$raiddev = $dir;
				local $m = $mdstat{$dir->{'value'}};
				$dir->{'active'} = $m->[0] eq 'active';
				$dir->{'level'} = $m->[1] =~ /raid(\d+)/ ? $1 : $m->[1];
				$dir->{'devices'} = [
					map { /(\S+)\[\d+\](\((.)\))?/;
					      $3 eq 'F' ? () : ("/dev/$1") }
					    split(/\s+/, $m->[2]) ];
				$dir->{'size'} = $m->[3];
				$dir->{'resync'} = $m->[4];
				$dir->{'errors'} = &disk_errors($m->[5]);
				}
			}
		$lnum++;
		}
	close(RAID);
	}
else {
	# Fake up the same format from mdadm output
	local $m;
	foreach $m (sort { $a cmp $b } keys %mdstat) {
		local $md = { 'value' => $m,
			      'members' => [ ],
			      'index' => scalar(@get_raidtab_cache) };
		local $mdstat = $mdstat{$md->{'value'}};
		$md->{'active'} = $mdstat->[0] eq 'active';
		$md->{'level'} = $mdstat->[1] =~ /raid(\d+)/ ? $1 : $mdstat->[1];
		$md->{'devices'} = [
			map { /(\S+)\[\d+\](\((.)\))?/;
			      $3 eq 'F' ? () : (&convert_to_hd("/dev/$1")) }
			    split(/\s+/, $mdstat->[2]) ];
		$md->{'size'} = $mdstat->[3];
		$md->{'resync'} = $mdstat->[4];
		$md->{'errors'} = &disk_errors($mdstat->[5]);
		open(MDSTAT, "mdadm --detail $m |");
		while(<MDSTAT>) {
			if (/^\s*Raid\s+Level\s*:\s*(\S+)/) {
				local $lvl = $1;
				$lvl =~ s/^raid//;
				push(@{$md->{'members'}}, { 'name' => 'raid-level',
							    'value' => $lvl });
				}
			elsif (/^\s*Persistence\s*:\s*(.*)/) {
				push(@{$md->{'members'}},
					{ 'name' => 'persistent-superblock',
					  'value' => $1 =~ /is\s+persistent/ });
				}
			elsif (/^\s*State\s*:\s*(.*)/) {
				$md->{'state'} = $1;
				}
			elsif (/^\s*Rebuild\s+Status\s*:\s*(\d+)\s*\%/) {
				$md->{'rebuild'} = $1;
				}
			elsif (/^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*\S)\s+(\/\S+)/) {
				# A device line
				local $device = { 'name' => 'device',
						  'value' => $6,
						  'members' => [ ] };
				push(@{$device->{'members'}},
				     { 'name' => $5 eq 'spare' ? 'spare-disk'
							       : 'raid-disk',
				       'value' => $3 });
				push(@{$md->{'members'}}, $device);
				}
			elsif (/^\s+(Chunk\s+Size|Rounding)\s+:\s+(\d+)/i) {
				push(@{$md->{'members'}},
					{ 'name' => 'chunk-size',
					  'value' => $2 });
				}
			}
		close(MDSTAT);
		push(@get_raidtab_cache, $md);
		}
	}
return \@get_raidtab_cache;
}

# disk_errors(string)
# Converts an mdstat errors string into an array of disk statuses
sub disk_errors
{
if ($_[0] =~ /\[([0-9\/]+)\].*\[([A-Z_]+)\]/i) {
	local ($idxs, $errs) = ($1, $2);
	local @idxs = split(/\//, $idxs);
	local @errs = split(//, $errs);
	#if (@idxs == @errs) {
	#	return [ map { $errs[$_-1] } @idxs ];
	#	}
	return \@errs;
	}
return undef;
}

sub lock_raid_files
{
&lock_file($raid_mode eq "raidtools" ? $config{'raidtab'} : $config{'mdadm'});
}

sub unlock_raid_files
{
&unlock_file($raid_mode eq "raidtools" ? $config{'raidtab'} : $config{'mdadm'});
}

# create_raid(&raid)
# Create a new raid set in the configuration file
sub create_raid
{
if ($raid_mode eq "raidtools") {
	# Add to /etc/raidtab
	local $lref = &read_file_lines($config{'raidtab'});
	$_[0]->{'line'} = @$lref;
	push(@$lref, &directive_lines($_[0]));
	$_[0]->{'eline'} = @$lref - 1;
	&flush_file_lines();
	}
else {
	# Add to /etc/mdadm.conf
	local ($d, @devices);
	foreach $d (&find("device", $_[0]->{'members'})) {
		push(@devices, $d->{'value'});
		}
	local $lref = &read_file_lines($config{'mdadm'});
	local $lvl = &find_value('raid-level', $_[0]->{'members'});
	$lvl = $lvl =~ /^\d+$/ ? "raid$lvl" : $lvl;
	push(@$lref, "DEVICE ".join(" ", @devices));
	push(@$lref, "ARRAY $_[0]->{'value'} level=$lvl devices=".
		     join(",", @devices));
	&flush_file_lines();
	}
}

# delete_raid(&raid)
# Delete a raid set from the config file
sub delete_raid
{
if ($raid_mode eq "raidtools") {
	# Remove from /etc/raidtab
	local $lref = &read_file_lines($config{'raidtab'});
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
	&flush_file_lines();
	}
else {
	# Remove from /etc/mdadm.conf
	local ($d, %devices);
	foreach $d (&find("device", $_[0]->{'members'})) {
		$devices{$d->{'value'}} = 1;
		}
	local $lref = &read_file_lines($config{'mdadm'});
	local $i;
	for($i=0; $i<@$lref; $i++) {
		if ($lref->[$i] =~ /^ARRAY\s+(\S+)/ && $1 eq $_[0]->{'value'}) {
			splice(@$lref, $i--, 1);
			}
		elsif ($lref->[$i] =~ /^DEVICE\s+(.*)/) {
			local @olddevices = split(/\s+/, $1);
			local @newdevices = grep { !$devices{$_} } @olddevices;
			if (@newdevices) {
				$lref->[$i] = "DEVICE ".join(" ", @newdevices);
				}
			else {
				splice(@$lref, $i--, 1);
				}
			}
		}
	&flush_file_lines();
	}
}

# make_raid(&raid, force)
# Call mkraid or mdadm to make a raid set for real
sub make_raid
{
if ($raid_mode eq "raidtools") {
	# Call the raidtools mkraid command
	local $f = $_[1] ? "--really-force" : "";
	local $out = &backquote_logged("mkraid $f $_[0]->{'value'} ".
				       "2>&1 </dev/null");
	return $? ? &text($out =~ /force/i ? 'eforce' : 'emkraid',
			  "<pre>$out</pre>")
		  : undef;
	}
else {
	# Call the complete mdadm command
	local $lvl = &find_value("raid-level", $_[0]->{'members'});
	$lvl =~ s/^raid//;
	local $chunk = &find_value("chunk-size", $_[0]->{'members'});
	local $mode = &find_value("persistent-superblock", $_[0]->{'members'}) ? "create" : "build";
	local $parity = &find_value("parity-algorithm", $_[0]->{'members'});
	local ($d, @devices, @spares, @parities);
	foreach $d (&find("device", $_[0]->{'members'})) {
		if (&find("raid-disk", $d->{'members'})) {
			push(@devices, $d->{'value'});
			}
		elsif (&find("spare-disk", $d->{'members'})) {
			push(@spares, $d->{'value'});
			}
		elsif (&find("parity-disk", $d->{'members'})) {
			# XXX how to handle?
			push(@parities, $d->{'value'});
			}
		}
	local $cmd = "mdadm --$mode --level $lvl --chunk $chunk";
	$cmd .= " --parity $parity" if ($parity);
	$cmd .= " --raid-devices ".scalar(@devices);
	$cmd .= " --spare-devices ".scalar(@spares) if (@spares);
	$cmd .= " --force" if ($_[1]);
	$cmd .= " --run";
	$cmd .= " $_[0]->{'value'}";
	foreach $d (@devices, @parities, @spares) {
		$cmd .= " $d";
		}
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	return $? ? &text('emdadmcreate', "<pre>$out</pre>") : undef;
	}
}

# unmake_raid(&raid)
# Shut down a RAID set permanently
sub unmake_raid
{
if ($raid_mode eq "raidtools") {
	&deactivate_raid($_[0]) if ($_[0]->{'active'});
	}
else {
	local $out = &backquote_logged("mdadm --stop $_[0]->{'value'} 2>&1");
	&error(&text('emdadmstop', "<tt>$out</tt>")) if ($?);
	}
}

# activate_raid(&raid)
# Activate a raid set, which has previously been deactivated
sub activate_raid
{
if ($raid_mode eq "raidtools") {
	local $out = &backquote_logged("raidstart $_[0]->{'value'} 2>&1");
	&error(&text('eraidstart', "<tt>$out</tt>")) if ($?);
	}
}

# deactivate_raid(&raid)
# Deactivate a raid set, without actually deleting it
sub deactivate_raid
{
if ($raid_mode eq "raidtools") {
	# Just stop the raid set
	local $out = &backquote_logged("raidstop $_[0]->{'value'} 2>&1");
	&error(&text('eraidstop', "<tt>$out</tt>")) if ($?);
	}
}

# add_partition(&raid, device)
# Adds a device to some RAID set, both in the config file and for real
sub add_partition
{
if ($raid_mode eq "mdadm") {
	# Call mdadm command to add
	local $out = &backquote_logged(
		"mdadm --manage $_[0]->{'value'} --add $_[1] 2>&1");
	&error(&text('emdadmadd', "<tt>$out</tt>")) if ($?);

	# Add device to mdadm.conf
	local $lref = &read_file_lines($config{'mdadm'});
	local ($i, $done_device);
	for($i=0; $i<@$lref; $i++) {
		if ($lref->[$i] =~ /^DEVICE\s+/ && !$done_device) {
			$lref->[$i] .= " $_[1]";
			$done_device++;
			}
		elsif ($lref->[$i] =~ /^ARRAY\s+(\S+)/ &&
		       $1 eq $_[0]->{'value'}) {
			$lref->[$i] =~ s/devices=(\S+)/devices=$1,$_[1]/;
			}
		}
	&flush_file_lines();
	}
}

# remove_partition(&raid, device)
# Removes a device from some RAID set, both in the config file and for real
sub remove_partition
{
if ($raid_mode eq "mdadm") {
	# Call mdadm commands to fail and remove
	local $out = &backquote_logged(
		"mdadm --manage $_[0]->{'value'} --fail $_[1] 2>&1");
	&error(&text('emdadfail', "<tt>$out</tt>")) if ($?);
	local $out = &backquote_logged(
		"mdadm --manage $_[0]->{'value'} --remove $_[1] 2>&1");
	&error(&text('emdadremove', "<tt>$out</tt>")) if ($?);

	# Remove device from mdadm.conf
	local $lref = &read_file_lines($config{'mdadm'});
	local ($i, $done_device);
	for($i=0; $i<@$lref; $i++) {
		if ($lref->[$i] =~ /^DEVICE\s+(.*)/) {
			local @olddevices = split(/\s+/, $1);
			local @newdevices = grep { $_ ne $_[1] } @olddevices;
			if (@newdevices) {
				$lref->[$i] = "DEVICE ".join(" ", @newdevices);
				}
			else {
				splice(@$lref, $i--, 1);
				}
			}
		elsif ($lref->[$i] =~ /^ARRAY\s+(\S+)/ &&
		       $1 eq $_[0]->{'value'}) {
			$lref->[$i] =~ s/((=)|,)\Q$_[1]\E/$2/;
			}
		}
	&flush_file_lines();
	}
}

# directive_lines(&directive, indent)
sub directive_lines
{
local @rv = ( "$_[1]$_[0]->{'name'}\t$_[0]->{'value'}" );
foreach $m (@{$_[0]->{'members'}}) {
	push(@rv, &directive_lines($m, $_[1]."\t"));
	}
return @rv;
}

# find(name, &array)
sub find
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &array)
sub find_value
{
local(@v);
@v = &find($_[0], $_[1]);
if (!@v) { return undef; }
elsif (wantarray) { return map { $_->{'value'} } @v; }
else { return $v[0]->{'value'}; }
}

# device_status(device)
# Returns an array of  directory, type, mounted
sub device_status
{
@mounted = &foreign_call("mount", "list_mounted") if (!@mounted);
@mounts = &foreign_call("mount", "list_mounts") if (!@mounts);
local $label = &fdisk::get_label($_[0]);

local ($mounted) = grep { &same_file($_->[1], $_[0]) ||
			  $_->[1] eq "LABEL=$label" } @mounted;
local ($mount) = grep { &same_file($_->[1], $_[0]) ||
			$_->[1] eq "LABEL=$label" } @mounts;
if ($mounted) { return ($mounted->[0], $mounted->[2], 1,
			&indexof($mount, @mounts),
			&indexof($mounted, @mounted)); }
elsif ($mount) { return ($mount->[0], $mount->[2], 0,
			 &indexof($mount, @mounts)); }
if (!defined(@physical_volumes)) {
	@physical_volumes = ();
	foreach $vg (&foreign_call("lvm", "list_volume_groups")) {
		push(@physical_volumes,
			&foreign_call("lvm", "list_physical_volumes",
					     $vg->{'name'}));
		}
	}
foreach $pv (@physical_volumes) {
	return ( $pv->{'vg'}, "lvm", 1)
		if ($pv->{'device'} eq $_[0]);
	}
return ();
}

# find_free_partitions(&skip, showtype, showsize)
sub find_free_partitions
{
&foreign_require("fdisk", "fdisk-lib.pl");
&foreign_require("mount", "mount-lib.pl");
&foreign_require("lvm", "lvm-lib.pl");
local %skip = map { $_, 1 } @{$_[0]};
local %used;
local $c;
local $conf = &get_raidtab();
foreach $c (@$conf) {
	foreach $d (&find_value('device', $c->{'members'})) {
		$used{$d}++;
		}
	}
local $disks;
local $d;
foreach $d (&fdisk::list_disks_partitions()) {
	foreach $p (@{$d->{'parts'}}) {
		next if ($used{$p->{'device'}} || $p->{'extended'} ||
			 $skip{$p->{'device'}});
		local @st = &device_status($p->{'device'});
		next if (@st);
		$tag = &foreign_call("fdisk", "tag_name", $p->{'type'});
		$p->{'blocks'} =~ s/\+$//;
		$disks .= sprintf "<option value='%s'>%s%s%s\n",
			$p->{'device'}, $p->{'desc'},
			$tag && $_[1] ? " ($tag)" : "",
			!$_[2] ? "" :
			$d->{'cylsize'} ? " (".&nice_size($d->{'cylsize'}*($p->{'end'} - $p->{'start'} + 1)).")" :
			" ($p->{'blocks'} $text{'blocks'})";
		}
	}
foreach $c (@$conf) {
	next if (!$c->{'active'} || $used{$c->{'value'}});
	local @st = &device_status($c->{'value'});
	next if (@st || $skip{$c->{'value'}});
	$disks .= sprintf "<option value='%s'>%s\n",
		$c->{'value'}, &text('create_rdev',
		    $c->{'value'} =~ /md(\d+)$/ ? "$1" : $c->{'value'});
	}
local $vg;
foreach $vg (&lvm::list_volume_groups()) {
	local $lv;
	foreach $lv (&foreign_call("lvm", "list_logical_volumes",
				   $vg->{'name'})) {
		next if ($lv->{'perm'} ne 'rw' || $used{$lv->{'device'}} ||
			 $skip->{$lv->{'device'}});
		local @st = &device_status($lv->{'device'});
		next if (@st);
		$disks .= sprintf "<option value='%s'>%s\n",
			$lv->{'device'},
			&text('create_lvm', $lv->{'vg'}, $lv->{'name'});
		}
	}
return $disks;
}

# convert_to_hd(device)
# Converts a device file like /dev/ide/host0/bus0/target1/lun0/part1 to
# /dev/hdb1, if it doesn't actually exist.
sub convert_to_hd
{
local ($dev) = @_;
return $dev if (-r $dev);
if ($dev =~ /ide\/host(\d+)\/bus(\d+)\/target(\d+)\/lun(\d+)\/part(\d+)/) {
	local ($host, $bus, $target, $lun, $part) = ($1, $2, $3, $4, $5);
	return "/dev/".&fdisk::hbt_to_device($host, $bus, $target).$part;
	}
else {
	return $dev;
	}
}

1;

