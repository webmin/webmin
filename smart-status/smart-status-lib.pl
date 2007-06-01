# Functions for getting SMART status

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
$extra_args = $config{'extra'};
if ($config{'ata'}) {
	$extra_args .= " -d ata";
	}

# get_smart_version()
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

# get_drive_status(device)
# Returns a hash reference containing the status of some drive
sub get_drive_status
{
local %rv;
local $qd = quotemeta($_[0]);
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

# short_test(drive)
# Starts a short drive test, and returns 1 for success or 0 for failure, plus
# any output.
sub short_test
{
if (&get_smart_version() > 5.0) {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -t short $_[0] 2>&1");
	if ($? || $out !~ /testing has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
else {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -S $_[0] 2>&1");
	if ($? || $out !~ /test has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
}

# ext_test(drive)
# Starts an extended drive test, and returns 1 for success or 0 for failure,
# plus any output.
sub ext_test
{
if (&get_smart_version() > 5.0) {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -t long $_[0] 2>&1");
	if ($? || $out !~ /testing has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
else {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -X $_[0] 2>&1");
	if ($? || $out !~ /test has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
}

# data_test(drive)
# Starts offline data collection, and returns 1 for success or 0 for failure,
# plus any output.
sub data_test
{
if (&get_smart_version() > 5.0) {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -t offline $_[0] 2>&1");
	if ($? || $out !~ /testing has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
else {
	local $out = &backquote_logged("$config{'smartctl'} $extra_args -O $_[0] 2>&1");
	if ($? || $out !~ /test has begun/i) {
		return (0, $out);
		}
	else {
		return (1, $out);
		}
	}
}

1;

