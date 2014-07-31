# Functions for getting and setting the timezone on Linux

$timezones_file = "/usr/share/zoneinfo/zone.tab";
$currentzone_link = "/etc/localtime";
$currentzone_file = "/etc/timezone";
$timezones_dir = "/usr/share/zoneinfo";
$sysclock_file = "/etc/sysconfig/clock";

# list_timezones()
sub list_timezones
{
local @rv;
local %done;
&open_readfile(ZONE, $timezones_file) || return ( );
while(<ZONE>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^(\S+)\s+(\S+)\s+(\S+)\s+(\S.*)/) {
		push(@rv, [ $3, $4 ]);
		$done{$3}++;
		}
	elsif (/^(\S+)\s+(\S+)\s+(\S+)/) {
		push(@rv, [ $3, undef ]);
		$done{$3}++;
		}
	}
close(ZONE);
push(@rv, [ "GMT", "GMT" ]) if (!$done{'GMT'});
push(@rv, [ "UTC", "UTC" ]) if (!$done{'UTC'});
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_current_timezone()
sub get_current_timezone
{
local $lnk = readlink(&translate_filename($currentzone_link));
if ($lnk) {
	# Easy - it a link
	$lnk =~ s/^\.\.//;
	$lnk =~ s/$timezones_dir\///;
	return $lnk;
	}
else {
	# Need to compare with all timezone files!
	return &find_same_zone($currentzone_link);
	}
}

# set_current_timezone(zone)
sub set_current_timezone
{
&lock_file($currentzone_link);
unlink(&translate_filename($currentzone_link));
symlink(&translate_filename("$timezones_dir/$_[0]"),
	&translate_filename($currentzone_link));
&unlock_file($currentzone_link);

if (-r $currentzone_file) {
	# This file is used on Debian systems
	&open_lock_tempfile(FILE, ">$currentzone_file");
	&print_tempfile(FILE, $_[0],"\n");
	&close_tempfile(FILE);
	}

local %clock;
if (&read_env_file($sysclock_file, \%clock)) {
	$clock{'ZONE'} = $_[0];
	&lock_file($sysclock_file);
	&write_env_file($sysclock_file, \%clock);
	&unlock_file($sysclock_file);
	}
}

sub os_has_timezones
{
return -r $timezones_file;
}

sub timezone_files
{
local @rv = ( $currentzone_link );
push(@rv, $currentzone_file) if (-r $currentzone_file);
push(@rv, $sysclock_file) if (-r $sysclock_file);
return @rv;
}

1;

