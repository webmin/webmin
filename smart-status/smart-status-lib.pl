=head1 smart-status-lib.pl

Functions for getting SMART status

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
=head2 get_smart_version()

Returns the version number of the SMART tools on this system

=cut
sub get_smart_version
{
if (!defined($smartctl_version_cache)) {
	local $out = &backquote_command(
			"$config{'smartctl'} --version 2>&1 </dev/null");
	if ($out =~ /smartmontools release\s+(\S+)/i) {
		$smartctl_version_cache = $1;
		}
	}
return $smartctl_version_cache;
}

=head2 list_smart_disks_partitions

Returns a sorted list of disks that can support SMART.

=cut
sub list_smart_disks_partitions
{
if (&foreign_check("fdisk")) {
	return &list_smart_disks_partitions_fdisk();
	}
elsif (&foreign_check("bsdfdisk")) {
	return &list_smart_disks_partitions_bsdfdisk();
	}
elsif (&foreign_check("mount")) {
	return &list_smart_disks_partitions_fstab();
	}
return ( );
}

=head2 list_smart_disks_partitions_fdisk

Returns a sorted list of disks that can support SMART, using the Linux fdisk
module. May include faked-up 3ware devices.

=cut
sub list_smart_disks_partitions_fdisk
{
&foreign_require("fdisk");
local @rv;
my $twcount = 0;
foreach my $d (sort { $a->{'device'} cmp $b->{'device'} }
		    &fdisk::list_disks_partitions()) {
	if (($d->{'type'} eq 'scsi' || $d->{'type'} eq 'raid') &&
	    $d->{'model'} =~ /3ware|amcc|9750/i) {
		# A 3ware hardware RAID device.

		# First find the controllers.
		local @ctrls = &list_3ware_controllers();

		# For each controller, find all the units (u0, u1, etc..)
		local @units;
		foreach my $c (@ctrls) {
			push(@units, &list_3ware_subdisks($c));
			}

		# Assume that /dev/sdX maps to units in order
		my $i = 0;
		foreach my $sd (@{$units[$twcount]->[2]}) {
			my $c = $units[$twcount]->[1];
			my $cidx = &indexof($c, @ctrls);
			my $dev = "/dev/twa".$cidx;
			if (!-r $dev) {
				$dev = "/dev/twe".$cidx;
				}
			if (!-r $dev) {
				$dev = "/dev/twl".$cidx;
				}
			push(@rv, { 'device' => $dev,
				    'prefix' => $dev,
				    'desc' => '3ware physical disk unit '.
				      $units[$twcount]->[0].' number '.$sd,
				    'type' => 'scsi',
				    'subtype' => '3ware',
				    'subdisk' => substr($sd, 1),
				    'id' => $d->{'id'},
				  });
			$i++;
			}
		$twcount++;
		}
	elsif (($d->{'type'} eq 'scsi' || $d->{'type'} eq 'raid') &&
	       $d->{'model'} =~ /LSI/i && $d->{'model'} !~ /9750/) {
		# A LSI megaraid device.
		local @units = &list_megaraid_subdisks(0);

		foreach my $i (@units) {
			push(@rv, { 'device' => $d->{'device'},
				    'prefix' => $d->{'device'},
				    'desc' => 'LSI Array '.$i->[1].' physical disk ID '.$i->[0],
				    'type' => 'scsi',
				    'subtype' => 'sat+megaraid',
				    'subdisk' => $i->[0],
				    'id' => $d->{'id'},
				  });
			}
		}
	elsif ($d->{'device'} =~ /^\/dev\/cciss\/(.*)$/) {
		# HP Smart Array .. add underlying disks
		my $count = &count_subdisks($d, "cciss");
		for(my $i=0; $i<$count; $i++) {
			push(@rv, { 'device' => $d->{'device'},
				    'prefix' => $d->{'device'},
				    'desc' => 'HP Smart Array physical disk '.$i,
				    'type' => 'scsi',
				    'subtype' => 'cciss',
				    'subdisk' => $i,
				    'id' => $d->{'id'},
				  });
			}
		}
	elsif ($d->{'type'} eq 'scsi' || $d->{'type'} eq 'ide') {
		# Some other disk
		push(@rv, $d);
		}
	}
return sort { $a->{'device'} cmp $b->{'device'} ||
	      $a->{'subdisk'} <=> $b->{'subdisk'} } @rv;
}

=head2 list_megaraid_subdisks(adapter)

Returns a list, each element of which is a unit, controller and list of subdisks

=cut
sub list_megaraid_subdisks
{
local ($adap) = @_;
local $out = &backquote_command("megacli -pdlist -a$adap");
return () if ($?);
my @rv;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^Device\sId:\s(\d+)$/) {
		push(@rv, [ $1, $adap, [ ] ]);
		}
	}
return @rv;
}

=head2 list_3ware_subdisks(controller)

Returns a list, each element of which is a unit, controller and list of subdisks

=cut
sub list_3ware_subdisks
{
local ($ctrl) = @_;
local $out = &backquote_command("tw_cli info $ctrl 2>/dev/null");
return () if ($?);
my @rv;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(u\d+)\s/) {
		push(@rv, [ $1, $ctrl, [ ] ]);
		}
	elsif ($l =~ /^(p\d+)\s+(\S+)\s+(\S+)/ &&
	       $2 ne 'NOT-PRESENT') {
		my ($u) = grep { $_->[0] eq $3 } @rv;
		if ($u) {
			push(@{$u->[2]}, $1);
			}
		}
	}
return @rv;
}

=head2 list_3ware_controllers()

Returns a list of 3ware controllers, each of which is just a string like c0

=cut
sub list_3ware_controllers
{
local $out = &backquote_command("tw_cli show 2>/dev/null");
return () if ($?);
my @rv;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(c\d+)\s/) {
		push(@rv, $1);
		}
	}
return @rv;
}

=head2 count_subdisks(&drive, type, [device])

Returns the number of sub-disks for a hardware RAID device, by calling
smartctl on them until failure.

=cut
sub count_subdisks
{
local ($d, $type, $device) = @_;
$device ||= $d->{'device'};
local $count = 0;
while(1) {
	local $cmd = "$config{'smartctl'} -d $type,$count ".quotemeta($device);
	&execute_command($cmd);
	last if ($?);
	$count++;
	}
return $count;
}

=head2 list_smart_disks_partitions_fstab

Returns a list of disks on which we can use SMART, taken from /etc/fstab.

=cut
sub list_smart_disks_partitions_fstab
{
&foreign_require("mount");
my @rv;
foreach my $m (&mount::list_mounted(1)) {
	if ($m->[1] =~ /^(\/dev\/(da|ad|ada)([0-9]+))/ &&
	    $m->[2] ne 'cd9660') {
		# FreeBSD-style disk name
		push(@rv, { 'device' => $1,
			    'desc' => ($2 eq 'ad' ? 'IDE' : 'SCSI').
				      ' disk '.$3 });
		}
	elsif ($m->[1] =~ /^(\/dev\/disk\d+)/ &&
	       ($m->[2] eq 'ufs' || $m->[2] eq 'hfs')) {
		# MacOS disk name
		push(@rv, { 'device' => $1,
			    'desc' => $1 });
		}
	elsif ($m->[1] =~ /^(\/dev\/([hs])d([a-z]))/ &&
	       $m->[2] ne 'iso9660') {
		# Linux disk name
		push(@rv, { 'device' => $1,
			    'desc' => ($2 eq 'h' ? 'IDE' : 'SCSI').
				      ' disk '.uc($3) });
		}
	}
my %done;
@rv = grep { !$done{$_->{'device'}}++ } @rv;
return @rv;
}

=head2 list_smart_disks_partitions_bsdfdisk

Returns a sorted list of disks that can support SMART, using the FreeBSD
fdisk module

=cut
sub list_smart_disks_partitions_bsdfdisk
{
&foreign_require("bsdfdisk");
local @rv;
foreach my $d (sort { $a->{'device'} cmp $b->{'device'} }
		    &bsdfdisk::list_disks_partitions()) {
	if ($d->{'type'} eq 'scsi' || $d->{'type'} eq 'ide') {
		push(@rv, $d);
		}
	}
return sort { $a->{'device'} cmp $b->{'device'} } @rv;
}

=head2 get_drive_status(device-name, [&drive])

Returns a hash reference containing the status of some drive

=cut
sub get_drive_status
{
local ($device, $drive) = @_;
local %rv;
local $qd = quotemeta($device);
local $extra_args = &get_extra_args($device, $drive);
if (&get_smart_version() > 5.0) {
	# Use new command format

	# Check support
	local $out = &backquote_command(
			"$config{'smartctl'} $extra_args  -i $qd 2>&1");
	if ($out =~ /SMART\s+support\s+is:\s+Available/i) {
		$rv{'support'} = 1;
		}
	elsif ($out =~ /Device\s+supports\s+SMART/i) {
		$rv{'support'} = 1;
		}
	else {
		$rv{'support'} = 0;
		}
	if ($out =~ /SMART\s+support\s+is:\s+Enabled/i) {
		$rv{'enabled'} = 1;
		}
	elsif ($out =~ /Device.*is\+Enabled/i) {
		$rv{'enabled'} = 1;
		}
	elsif ($out =~ /Device\s+supports\s+SMART\s+and\s+is\s+Enabled/i) {
		# Added to match output from RHEL5
		$rv{'enabled'} = 1;
		}
	else {
		# Not enabled!
		$rv{'enabled'} = 0;
		}
	if (!$rv{'support'} || !$rv{'enabled'}) {
		# No point checking further!
		return \%rv;
		}

	# Check status
	$out = &backquote_command(
		"$config{'smartctl'} $extra_args -H $qd 2>&1");
	if ($out =~ /test result: FAILED/i) {
		$rv{'check'} = 0;
		}
	else {
		$rv{'check'} = 1;
		}
	}
else {
	# Use old command format

	# Check status
	local $out = &backquote_command(
			"$config{'smartctl'} $extra_args -c $qd 2>&1");
	if ($out =~ /supports S.M.A.R.T./i) {
		$rv{'support'} = 1;
		}
	else {
		$rv{'support'} = 0;
		}
	if ($out =~ /is enabled/i) {
		$rv{'enabled'} = 1;
		}
	else {
		# Not enabled!
		$rv{'enabled'} = 0;
		}
	if (!$rv{'support'} || !$rv{'enabled'}) {
		# No point checking further!
		return \%rv;
		}
	if ($out =~ /Check S.M.A.R.T. Passed/i) {
		$rv{'check'} = 1;
		}
	else {
		$rv{'check'} = 0;
		}
	}

if ($config{'attribs'}) {
	# Fetch other attributes
	local ($lastline, @attribs);
	local $doneknown = 0;
	$rv{'raw'} = "";
	open(OUT, "$config{'smartctl'} $extra_args -a $qd |");
	while(<OUT>) {
		s/\r|\n//g;
		if (/Model\s+Family:\s+(.*)/i) {
			$rv{'family'} = $1;
			}
		elsif (/Device\s+Model:\s+(.*)/i) {
			$rv{'model'} = $1;
			}
		elsif (/Serial\s+Number:\s+(.*)/i) {
			$rv{'serial'} = $1;
			}
		elsif (/User\s+Capacity:\s+(.*)/i) {
			$rv{'capacity'} = $1;
			}
		if (/^\((\s*\d+)\)(.*)\s(0x\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			# An old-style vendor attribute
			$doneknown = 1;
			push(@attribs, [ $2, $7 ]);
			}
		elsif (/^\s*(\d+)\s+(\S+)\s+(0x\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			# A new-style vendor attribute
			$doneknown = 1;
			push(@attribs, [ $2, $10, undef, $4 ]);
			$attribs[$#attribs]->[0] =~ s/_/ /g;
			}
		elsif (/^(\S.*\S):\s+\(\s*(\S+)\)\s*(.*)/ && !$doneknown) {
			# A known attribute
			local $attrib = [ $1, $2, $3 ];
			if ($lastline =~ /^\S/ && $lastline !~ /:/) {
				$attrib->[0] = $lastline." ".$attrib->[0];
				}
			push(@attribs, $attrib);
			}
		elsif (/^\s+(\S.*)/ && @attribs && !$doneknown) {
			# Continuation of a known attribute description
			local $cont = $1;
			local $ls = $attribs[$#attribs];
			if ($ls->[2] =~ /\.\s*$/) {
				$ls->[2] .= "<br>".$cont;
				}
			else {
				$ls->[2] .= " ".$cont;
				}
			}
		elsif (/ATA\s+Error\s+Count:\s+(\d+)/i) {
			# An error line!
			$rv{'errors'} = $1;
			}
		$lastline = $_;
		$rv{'raw'} .= $_."\n";
		}
	close(OUT);
	$rv{'attribs'} = \@attribs;
	}
return \%rv;
}

# short_test(device, [&drive])
# Starts a short drive test, and returns 1 for success or 0 for failure, plus
# any output.
sub short_test
{
local ($device, $drive) = @_;
local $qm = quotemeta($device);
local $extra_args = &get_extra_args($device, $drive);
if (&get_smart_version() > 5.0) {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -t short $qm 2>&1");
	if ($? || $out !~ /testing has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
else {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -S $qm 2>&1");
	if ($? || $out !~ /test has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
}

# ext_test(device, [&drive])
# Starts an extended drive test, and returns 1 for success or 0 for failure,
# plus any output.
sub ext_test
{
local ($device, $drive) = @_;
local $qm = quotemeta($device);
local $extra_args = &get_extra_args($device, $drive);
if (&get_smart_version() > 5.0) {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -t long $qm 2>&1");
	if ($? || $out !~ /testing has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
else {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -X $qm 2>&1");
	if ($? || $out !~ /test has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
}

# data_test(device, [&drive])
# Starts offline data collection, and returns 1 for success or 0 for failure,
# plus any output.
sub data_test
{
local ($device, $drive) = @_;
local $qm = quotemeta($device);
local $extra_args = &get_extra_args($device, $drive);
if (&get_smart_version() > 5.0) {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -t offline $qm 2>&1");
	if ($? || $out !~ /testing has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
else {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -O $qm 2>&1");
	if ($? || $out !~ /test has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
}

=head2 get_extra_args(device, [&drive])

Returns extra command-line args to smartctl, needed for some drive type.

=cut
sub get_extra_args
{
local ($device, $drive) = @_;
if (!$drive) {
	($drive) = grep { $_->{'device'} eq $device }
			&list_smart_disks_partitions();
	}
local $extra_args = $config{'extra'};
if ($drive && defined($drive->{'subdisk'})) {
	$extra_args .= " -d $drive->{'subtype'},$drive->{'subdisk'}";
	}
elsif ($config{'ata'}) {
	$extra_args .= " -d ata";
	}
return $extra_args;
}

1;

