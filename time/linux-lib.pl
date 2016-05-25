# Functions for getting and setting the timezone on Linux

use strict;
use warnings;
our $timezones_file = "/usr/share/zoneinfo/zone.tab";
our $currentzone_link = "/etc/localtime";
our $currentzone_file = "/etc/timezone";
our $timezones_dir = "/usr/share/zoneinfo";
our $sysclock_file = "/etc/sysconfig/clock";

# list_timezones()
sub list_timezones
{
my @rv;
my %done;
my $fh = "ZONE";
&open_readfile($fh, $timezones_file) || return ( );
while(<$fh>) {
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
close($fh);
push(@rv, [ "GMT", "GMT" ]) if (!$done{'GMT'});
push(@rv, [ "UTC", "UTC" ]) if (!$done{'UTC'});
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_current_timezone()
sub get_current_timezone
{
my $lnk = readlink(&translate_filename($currentzone_link));
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
my ($zone) = @_;
&lock_file($currentzone_link);
unlink(&translate_filename($currentzone_link));
symlink(&translate_filename("$timezones_dir/$zone"),
	&translate_filename($currentzone_link));
&unlock_file($currentzone_link);

if (-r $currentzone_file) {
	# This file is used on Debian systems
	my $fh = "FILE";
	&open_lock_tempfile($fh, ">$currentzone_file");
	&print_tempfile($fh, $zone,"\n");
	&close_tempfile($fh);
	}

my %clock;
if (&read_env_file($sysclock_file, \%clock)) {
	$clock{'ZONE'} = $zone;
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
my @rv = ( $currentzone_link );
push(@rv, $currentzone_file) if (-r $currentzone_file);
push(@rv, $sysclock_file) if (-r $sysclock_file);
return @rv;
}

1;

