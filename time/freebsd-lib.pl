# Functions for getting and setting the timezone on Linux

use strict;
use warnings;
our $timezones_file = "/usr/share/zoneinfo/zone.tab";
our $currentzone_link = "/etc/localtime";
our $timezones_dir = "/usr/share/zoneinfo";

# list_timezones()
sub list_timezones
{
my @rv;
my $fh = "ZONE";
&open_readfile($fh, $timezones_file) || return ( );
while(<$fh>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^(\S+)\s+(\S+)\s+(\S+)\s+(\S.*)/) {
		push(@rv, [ $3, $4 ]);
		}
	elsif (/^(\S+)\s+(\S+)\s+(\S+)/) {
		push(@rv, [ $3, undef ]);
		}
	}
close($fh);
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_current_timezone()
sub get_current_timezone
{
my $lnk = readlink(&translate_filename($currentzone_link));
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
my ($zone) = @_;
&lock_file($currentzone_link);
unlink(&translate_filename($currentzone_link));
symlink(&translate_filename("$timezones_dir/$zone"),
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

