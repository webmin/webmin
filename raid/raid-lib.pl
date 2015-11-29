# raid-lib.pl
# Functions for managing RAID

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("fdisk");

open(MODE, "$module_config_directory/mode");
chop($raid_mode = <MODE>);
close(MODE);
$raid_mode ||= "mdadm";

%container = ( 'raiddev', 1,
	       'device', 1 );

# get_raid_levels()
# Returns a list of allowed RAID levels
sub get_raid_levels
{
if ($raid_mode eq "mdadm") {
	return ( 0, 1, 4, 5, 6, 10 );
	}
else {
	return ( 0, 1, 4, 5 );
	}
}

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
	if (/^(md\d+)\s*:\s+(\S+)\s+(\S+)\s+(.*)\s+(\d+)\s+blocks\s*(.*)resync=([0-9\.]+|delayed)/) {
		$mdstat{$lastdev = "/dev/$1"} = [ $2, $3, $4, $5, $7, $6 ];
		}
	elsif (/^(md\d+)\s*:\s+(\S+)\s+(\S+)\s+(.*)\s+(\d+)\s+blocks\s*(.*)/) {
		$mdstat{$lastdev = "/dev/$1"} = [ $2, $3, $4, $5, undef, $6 ];
		}
	elsif (/^(md\d+)\s*:\s+(\S+)\s+(\S+)\s+(.*)/) {
		$mdstat{$lastdev = "/dev/$1"} = [ $2, $3, $4 ];
		$_ = <MDSTAT>;
		if (/\s+(\d+)\s+blocks\s*(.*)resync=([0-9\.]+)/) {
			# Block count and resync progress after device line
			$mdstat{$lastdev}->[3] = $1;
			$mdstat{$lastdev}->[4] = $3;
			$mdstat{$lastdev}->[5] = $2;
			}
		elsif (/\s+(\d+)\s+blocks\s*(.*)/) {
			# Block count only after device line
			$mdstat{$lastdev}->[3] = $1;
			$mdstat{$lastdev}->[5] = $2;
			}
		}
	elsif (/^\s*\[\S+\]\s*(resync|recovery)\s*=\s([0-9\.]+)/) {
		# Resync section is on it's own line
		$mdstat{$lastdev}->[5] = $2;
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
return \@get_raidtab_cache if (scalar(@get_raidtab_cache));
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
				$dir->{'active'} = $m->[0] =~ /^active/;
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
		$md->{'active'} = $mdstat->[0] =~ /^active/;
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
			elsif ((/^\s*Rebuild\s+Status\s*:\s*([0-9\.]+)\s*\%/) || (/^\s*Reshape\s+Status\s*:\s*([0-9\.]+)\s*\%/) || (/^\s*Resync\s+Status\s*:\s*([0-9\.]+)\s*\%/)) {
				$md->{'rebuild'} = $1;
				}
			elsif (/^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+|\-)\s+(.*\S)\s+(\/\S+)/) {
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
			elsif (/^\s+Layout\s+:\s*(.*)/) {
                                push(@{$md->{'members'}},
                                        { 'name' => 'parity-algorithm',
                                          'value' => $1 });
                                }
			elsif (/^\s+UUID\s+:\s*(.*)/) {
                                push(@{$md->{'members'}},
                                        { 'name' => 'array-uuid',
                                          'value' => $1 });
                                }
			}
		close(MDSTAT);
		local $lastdev;
		open(MDSTAT, $config{'mdstat'});
		while(<MDSTAT>){
			if (/^(md\d+)/) {
		                $lastdev = "/dev/$1";
               			}
			if ((/^.*finish=(\S+)min/) && ($lastdev eq $m)) {
				$md->{'remain'} = $1;
				}
			if ((/^.*speed=(\S+)K/) && ($lastdev eq $m)) {
				$md->{'speed'} = $1;
				}
			}
		close(MDSTAT);
		push(@get_raidtab_cache, $md);
		}

	# Merge in info from mdadm.conf
	local $lref = &read_file_lines($config{'mdadm'});
	foreach my $l (@$lref) {
		if ($l =~ /^ARRAY\s+(\S+)\s*(.*)/) {
			local $dev = $1;
			local %opts = map { split(/=/, $_, 2) }
					  split(/\s+/, $2);
			local ($md) = grep { $_->{'value'} eq $dev }
					   @get_raidtab_cache;
			if ($md) {
				push(@{$md->{'members'}},
					{ 'name' => 'spare-group',
					  'value' => $opts{'spare-group'} });
				}
			}
		}
	}
return \@get_raidtab_cache;
}

# get_uuid(&raid)
# Get the UUID of an mdadm RAID after creation.
sub get_uuid
{
	open(MDSTAT, "mdadm --detail $_[0]->{'value'} |");
                while(<MDSTAT>) {
                        if (/^\s+UUID\s+:\s*(.*)/) {
				return $1;
                                }
                        }
                close(MDSTAT);
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
	# Add to mdadm.conf
	local $sg = &find_value("spare-group", $_[0]->{'members'});
	local $lref = &read_file_lines($config{'mdadm'});
	push(@$lref, "ARRAY $_[0]->{'value'} uuid=$_[1]". 
		     ($sg ? " spare-group=$sg" : ""));
	&flush_file_lines();
	&update_initramfs();
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
	&flush_file_lines($config{'raidtab'});
	}
else {
	# Zero out the RAID
	&system_logged("mdadm --zero-superblock ".
		       "$_[0]->{'value'} >/dev/null 2>&1");

	# Zero out component superblocks
	my @devs = &find('device', $_[0]->{'members'});
	foreach $d (@devs) {
		if (&find('raid-disk', $d->{'members'}) ||
		    &find('parity-disk', $d->{'members'}) ||
		    &find('spare-disk', $d->{'members'})) {
			&system_logged("mdadm --zero-superblock ".
				       "$d->{'value'} >/dev/null 2>&1");
			}
		}

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
	&flush_file_lines($config{'mdadm'});
	&update_initramfs();
	}
}

# device_to_volid(device)
# Given a device name like /dev/sda1, convert it to a volume ID if possible.
# Otherwise return the device name.
sub device_to_volid
{
local ($dev) = @_;
return $dev;
#return &fdisk::get_volid($dev) || $dev;
}

# make_raid(&raid, force, [missing], [assume-clean])
# Call mkraid or mdadm to make a raid set for real
sub make_raid
{
if (!-r $_[0]->{'value'} && $_[0]->{'value'} =~ /\/md(\d+)$/) {
	# Device file is missing - create it now
	&system_logged("mknod $_[0]->{'value'} b 9 $1");
	}
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
	local $layout = &find_value("parity-algorithm", $_[0]->{'members'});
	local ($d, @devices, @spares, @parities);
	foreach $d (&find("device", $_[0]->{'members'})) {
		if (&find("raid-disk", $d->{'members'})) {
			push(@devices, $d->{'value'});
			}
		elsif (&find("spare-disk", $d->{'members'})) {
			push(@spares, $d->{'value'});
			}
		elsif (&find("parity-disk", $d->{'members'})) {
			push(@parities, $d->{'value'});
			}
		}
	local $cmd = "mdadm --$mode --level $lvl";
	if ($_[2]) {
		push(@devices, "missing");
		}
	$cmd .= " --layout $layout" if ($layout);
	$cmd .= " --chunk $chunk" if ($chunk);
	$cmd .= " --raid-devices ".scalar(@devices);
	$cmd .= " --spare-devices ".scalar(@spares) if (@spares);
	$cmd .= " --force" if ($_[1]);
	$cmd .= " --assume-clean" if ($_[3]);
	$cmd .= " --run";
	$cmd .= " $_[0]->{'value'}";
	foreach $d (@devices, @parities, @spares) {
		$cmd .= " $d";
		}
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	
	return $? ? &text('emdadmcreate', "<pre>$out</pre>") : undef;
	}
}

# readwrite_raid(&raid)
# Set RAID mode to read/write.
sub readwrite_raid
{
	local $cmd = "mdadm --readwrite $_[0]->{'value'}";
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	return;
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
			$lref->[$i] =~ s/(\s)devices=(\S+)/${1}devices=${2},$_[1]/;
			}
		}
	&flush_file_lines();
	&update_initramfs();
	}
}

# grow(&raid, totaldisks)
# Grows a RAID set to contain totaldisks active partitions
sub grow
{
if ($raid_mode eq "mdadm") {
	# Call mdadm command to add
	$cmd="mdadm -G $_[0]->{'value'} -n $_[1] 2>&1";
	local $out = &backquote_logged(
		$cmd);
	&error(&text('emdadmgrow', "<tt>'$cmd' -> $out</tt>")) if ($?);
	}
}

# convert_raid(&raid, oldcount, newcount, level)
# Converts a RAID set to a defferent level RAID set
sub convert_raid
{
if ($raid_mode eq "mdadm") {
	if ($_[2]) {
		# Use backup file in case something goes wrong during critical section of reshape
		$raid_device_short = $_[0]->{'value'};
		$raid_device_short =~ s/\/dev\///;
		$date = `date \+\%Y\%m\%d-\%H\%M`;
		chomp($date);
		$backup_file = "/raid-level-convert-$raid_device_short-$date.bck";

		# Call mdadm command to convert
		$cmd="mdadm -G $_[0]->{'value'} -l $_[3] -n $_[2] --backup-file $backup_file 2>&1";
        
		local $out = &backquote_logged(
			$cmd);
		&error(&text('emdadmgrow', "<tt>'$cmd' -> $out</tt>")) if ($?);
		}
	else {
		$newcount = $_[1] - 1;
		$cmd="mdadm --grow $_[0]->{'value'} --level $_[3] -n $newcount";
		$raid_device_short = $_[0]->{'value'};
                $raid_device_short =~ s/\/dev\///;
                $date = `date \+\%Y\%m\%d-\%H\%M`;
                chomp($date);
                $cmd .= " --backup-file /tmp/convert-$raid_device_short-$date";
		local $out = &backquote_logged(
                        $cmd);
                &error(&text('emdadmgrow', "<tt>'$cmd' -> $out</tt>")) if ($?);
		}
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
	&error(&text('emdadmfail', "<tt>$out</tt>")) if ($?);
	local $out = &backquote_logged(
		"mdadm --manage $_[0]->{'value'} --remove $_[1] 2>&1");
	&error(&text('emdadmremove', "<tt>$out</tt>")) if ($?);

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
	&update_initramfs();
	}
}

# remove_detached(&raid)
# Removes detached device(s) from some RAID set
sub remove_detached
{
if ($raid_mode eq "mdadm") {
	# Call mdadm commands to remove
	local $out = &backquote_logged(
		"mdadm --manage $_[0]->{'value'} --remove detached 2>&1");
	&error(&text('emdadmremove', "<tt>$out</tt>")) if ($?);
	}
}

# replace_partition(&raid, device, spare) 
# Hot replaces a data disk with a spare disk
sub replace_partition
{
if ($raid_mode eq "mdadm") {
        # Call mdadm commands to replace
        local $out = &backquote_logged(
                "mdadm --replace $_[0]->{'value'} $_[1] --with $_[2] 2>&1");
        &error(&text('emdadmreplace', "<tt>$out</tt>")) if ($?);
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
return &fdisk::device_status($_[0]);
}

# find_free_partitions(&skip, showtype, showsize)
# Returns a list of options, suitable for ui_select
sub find_free_partitions
{
&foreign_require("fdisk");
&foreign_require("mount");
&foreign_require("lvm");
local %skip;
if ($_[0]) {
	%skip = map { $_, 1 } @{$_[0]};
	}
local %used;
local $c;
local $conf = &get_raidtab();
foreach $c (@$conf) {
	foreach $d (&find_value('device', $c->{'members'})) {
		$used{$d}++;
		}
	}
local @disks;
local $d;
foreach $d (&fdisk::list_disks_partitions()) {
	foreach $p (@{$d->{'parts'}}) {
		next if ($used{$p->{'device'}} || $used{$d->{'device'}} ||
			 $p->{'extended'} || $skip{$p->{'device'}});
		local @st = &device_status($p->{'device'});
		next if (@st);
		$tag = $p->{'type'} ? &fdisk::tag_name($p->{'type'}) : undef;
		$p->{'blocks'} =~ s/\+$//;
		push(@disks, [ $p->{'device'},
			       $p->{'desc'}.
			       ($tag && $_[1] ? " ($tag)" : "").
			       (!$_[2] ? "" :
				$d->{'cylsize'} ? " (".&nice_size($d->{'cylsize'}*($p->{'end'} - $p->{'start'} + 1)).")" :
				" ($p->{'blocks'} $text{'blocks'})") ]);
		}
	if (!@{$d->{'parts'}} &&
	    !$used{$d->{'device'}} && !$skip{$d->{'device'}}) {
		# Raw disk has no partitions - add it as an option
		push(@disks, [ $d->{'device'},
			       $d->{'desc'}.
			       ($d->{'cylsize'} ? " (".&nice_size($d->{'cylsize'}*$d->{'cylinders'}).")" : "") ]);
		}
	}
foreach $c (@$conf) {
	next if (!$c->{'active'} || $used{$c->{'value'}});
	local @st = &device_status($c->{'value'});
	next if (@st || $skip{$c->{'value'}});
	push(@disks, [ $c->{'value'},
		       &text('create_rdev',
		         $c->{'value'} =~ /md(\d+)$/ ? "$1" : $c->{'value'}) ]);
	}
local $vg;
foreach $vg (&lvm::list_volume_groups()) {
	local $lv;
	foreach $lv (&lvm::list_logical_volumes($vg->{'name'})) {
		next if ($lv->{'perm'} ne 'rw' || $used{$lv->{'device'}} ||
			 $skip->{$lv->{'device'}});
		local @st = &device_status($lv->{'device'});
		next if (@st);
		push(@disks, [ $lv->{'device'},
			      &text('create_lvm', $lv->{'vg'}, $lv->{'name'}) ]);
		}
	}
return sort { $a->[0] cmp $b->[0] } @disks;
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

%mdadm_notification_opts = map { $_, 1 } ( 'MAILADDR', 'MAILFROM', 'PROGRAM' );

# get_mdadm_notifications()
# Returns a hash from mdadm.conf notification-related settings to values
sub get_mdadm_notifications
{
local $lref = &read_file_lines($config{'mdadm'});
local %rv;
foreach my $l (@$lref) {
	$l =~ s/#.*$//;
	if ($l =~ /^(\S+)\s+(\S.*)/ && $mdadm_notification_opts{$1}) {
		$rv{$1} = $2;
		}
	}
return \%rv;
}

# save_mdadm_notifications(&notifications)
# Updates mdadm.conf with settings from the given hash. Those set to undef
# are removed from the file.
sub save_mdadm_notifications
{
local ($notif) = @_;
local $lref = &read_file_lines($config{'mdadm'});
local %done;
for(my $i=0; $i<@$lref; $i++) {
	my $l = $lref->[$i];
	$l =~ s/#.*$//;
	local ($k, $v) = split(/\s+/, $l, 2);
	if (exists($notif->{$k})) {
		if (defined($notif->{$k})) {
			$lref->[$i] = "$k $notif->{$k}";
			}
		else {
			splice(@$lref, $i--, 1);
			}
		$done{$k}++;
		}
	}
foreach my $k (grep { !$done{$_} && defined($notif->{$_}) } keys %$notif) {
	push(@$lref, "$k $notif->{$k}");
	}
&flush_file_lines($config{'mdadm'});
}

# get_mdadm_action()
# Returns the name of an init module action for mdadm monitoring, or undef if
# not supported.
sub get_mdadm_action
{
if (&foreign_installed("init")) {
	&foreign_require("init");
	foreach my $a ("mdmonitor", "mdadm", "mdadmd") {
		local $st = &init::action_status($a);
		return $a if ($st);
		}
	}
return undef;
}

# get_mdadm_monitoring()
# Returns 1 if mdadm monitoring is enabled, 0 if not
sub get_mdadm_monitoring
{
local $act = &get_mdadm_action();
if ($act) {
	&foreign_require("init");
	local $st = &init::action_status($act);
	return $st == 2;
	}
return 0;
}

# save_mdadm_monitoring(enabled)
# Tries to enable or disable mdadm monitoring. Returns an error mesage
# if something goes wrong, undef on success
sub save_mdadm_monitoring
{
local ($enabled) = @_;
local $act = &get_mdadm_action();
if ($act) {
	&foreign_require("init");
	if ($enabled) {
		&init::enable_at_boot($act);
		&init::stop_action($act);
		sleep(2);
		local ($ok, $err) = &init::start_action($act);
		return $err if (!$ok);
		}
	else {
		&init::disable_at_boot($act);
		&init::stop_action($act);
		}
	}
return undef;
}

# update_initramfs()
# If the update-initramfs command is installed, run it to update mdadm.conf
# in the ramdisk
sub update_initramfs
{
if (&has_command("update-initramfs")) {
	&system_logged("update-initramfs -u >/dev/null 2>&1 </dev/null");
	}
}

# get_mdadm_version()
# Returns the mdadm version number
sub get_mdadm_version
{
local $out = `mdadm --version 2>&1`;
local $ver = $out =~ /\s+v([0-9\.]+)/ ? $1 : undef;
return wantarray ? ( $ver, $out ) : $ver;
}

# supports_replace()
# Only kernels with version 3.3 and above support the hot replace feature
sub supports_replace
{
my $out = &backquote_command("uname -r 2>/dev/null </dev/null");
return $out =~ /^(\d+)\.(\d+)/ && $1 == 3 && $2 >= 3;
}

1;

