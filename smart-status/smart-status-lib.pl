=head1 smart-status-lib.pl

Functions for getting SMART status

=cut

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");

=head2 get_smart_version()

Returns the version number of the SMART tools on this system

=cut
sub get_smart_version
{
if (!defined($smartctl_version_cache)) {
	local $out = `$config{'smartctl'} -h 2>&1 </dev/null`;
	if ($out =~ /version\s+(\S+)/i) {
		$smartctl_version_cache = $1;
		}
	}
return $smartctl_version_cache;
}

=head2 list_smart_disks_partitions

Returns a sorted list of disks that can support SMART.
May include faked-up 3ware devices

=cut
sub list_smart_disks_partitions
{
local @drives = grep { $_->{'type'} eq 'ide' ||
		       $_->{'type'} eq 'scsi' } &fdisk::list_disks_partitions();
local @rv;
local $threecount = 0;
foreach my $d (@drives) {
	if ($d->{'type'} eq 'scsi' && $d->{'model'} =~ /3ware/i) {
		# Actually a 3ware RAID device .. but we want to probe the
		# underlying real disks, so add fake devices for them
		my $count = &count_3ware_disks($d);
		for(my $i=0; $i<$count; $i++) {
			push(@rv, { 'device' => '/dev/twe'.$threecount,
				    'prefix' => '/dev/twe'.$threecount,
				    'desc' => '3ware physical disk '.$i,
				    'type' => 'scsi',
				    '3ware' => $i,
				  });
			}
		$threecount++;
		}
	else {
		push(@rv, $d);
		}
	}
return sort { $a->{'device'} cmp $b->{'device'} ||
	      $a->{'3ware'} <=> $b->{'3ware'} } @rv;
}

=head2 count_3ware_disks(&drive)

Returns the number of physical disks on some 3ware RAID device.

=cut
sub count_3ware_disks
{
return 4;	# XXX
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
	local $out = `$config{'smartctl'} $extra_args  -i $qd 2>&1`;
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
	$out = `$config{'smartctl'} $extra_args -H $qd 2>&1`;
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
	local $out = `$config{'smartctl'} $extra_args -c $qd 2>&1`;
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
	open(OUT, "$config{'smartctl'} $extra_args -a $qd |");
	while(<OUT>) {
		s/\r|\n//g;
		if (/^\((\s*\d+)\)(.*)\s(0x\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			# An old-style vendor attribute
			$doneknown = 1;
			push(@attribs, [ $2, $7 ]);
			}
		elsif (/^\s*(\d+)\s+(\S+)\s+(0x\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			# A new-style vendor attribute
			$doneknown = 1;
			push(@attribs, [ $2, $10 ]);
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
			$attribs[$#attribs]->[2] .= "<br>".$1;
			}
		elsif (/ATA\s+Error\s+Count:\s+(\d+)/i) {
			# An error line!
			$rv{'errors'} = $1;
			}
		$lastline = $_;
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
if ($drive && defined($drive->{'3ware'})) {
	$extra_args .= " -d 3ware,$drive->{'3ware'}";
	}
elsif ($config{'ata'}) {
	$extra_args .= " -d ata";
	}
return $extra_args;
}

1;

