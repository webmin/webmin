# Functions for getting and setting the timezone on Linux

use strict;
use warnings;
our $timezone_file = "/etc/TIMEZONE";
our $timezones_dir = "/usr/share/lib/zoneinfo";
our $rtc_config = "/etc/rtc_config";

# list_timezones()
sub list_timezones
{
my @rv;
my $file;
my $fh = "FIND";
&open_execute_command($fh, "find $timezones_dir -type f", 1);
while($file = <$fh>) {
	chop($file);
	my $buf;
	my $fh2 = "INFO";
	&open_readfile($fh2, $file);
	read($fh2, $buf, 2);
	close($fh2);
	if ($buf eq "TZ") {
		# A timezone file we can use!
		$file =~ s/^$timezones_dir\///;
		push(@rv, [ $file, undef ]);
		}
	}
close($fh);
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_current_timezone()
sub get_current_timezone
{
my %tz;
&read_env_file($timezone_file, \%tz);
$tz{'TZ'} =~ s/^://;
return $tz{'TZ'};
}

# set_current_timezone(zone)
sub set_current_timezone
{
my %tz;
&lock_file($timezone_file);
&read_env_file($timezone_file, \%tz);
$tz{'TZ'} = $_[0];
&write_env_file($timezone_file, \%tz);
&unlock_file($timezone_file);

if (-r $rtc_config) {
	# Update x86 RTC timezone too
	&lock_file($rtc_config);
	my %rtc;
	&read_env_file($rtc_config, \%rtc);
	$rtc{'zone_info'} = $_[0];
	&write_env_file($rtc_config, \%rtc);
	&unlock_file($rtc_config);
	}
}

sub os_has_timezones
{
return -r $timezone_file && -d $timezones_dir;
}

sub timezone_files
{
return ( $timezone_file );
}

1;

