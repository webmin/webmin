# Functions for getting and setting the timezone on Linux

$timezones_file = "/usr/share/zoneinfo/zone.tab";
$currentzone_link = "/etc/localtime";
$timezones_dir = "/usr/share/zoneinfo";

# list_timezones()
sub list_timezones
{
local @rv;
&open_readfile(ZONE, $timezones_file) || return ( );
while(<ZONE>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^(\S+)\s+(\S+)\s+(\S+)\s+(\S.*)/) {
		push(@rv, [ $3, $4 ]);
		}
	elsif (/^(\S+)\s+(\S+)\s+(\S+)/) {
		push(@rv, [ $3, undef ]);
		}
	}
close(ZONE);
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_current_timezone()
sub get_current_timezone
{
local $lnk = readlink(&translate_filename($currentzone_link));
if ($lnk) {
	# Easy - it a link
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
}

sub os_has_timezones
{
return -r $timezones_file;
}

sub timezone_files
{
return ( $currentzone_link );
}

1;

