# Functions for getting and setting the timezone on Linux

$timezone_file = "/etc/TIMEZONE";
$timezones_dir = "/usr/share/lib/zoneinfo";
$rtc_config = "/etc/rtc_config";

# list_timezones()
sub list_timezones
{
local @rv;
local $file;
&open_execute_command(FIND, "find $timezones_dir -type f", 1);
while($file = <FIND>) {
	chop($file);
	local $buf;
	&open_readfile(INFO, $file);
	read(INFO, $buf, 2);
	close(INFO);
	if ($buf eq "TZ") {
		# A timezone file we can use!
		$file =~ s/^$timezones_dir\///;
		push(@rv, [ $file, undef ]);
		}
	}
close(FIND);
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_current_timezone()
sub get_current_timezone
{
local %tz;
&read_env_file($timezone_file, \%tz);
$tz{'TZ'} =~ s/^://;
return $tz{'TZ'};
}

# set_current_timezone(zone)
sub set_current_timezone
{
local %tz;
&lock_file($timezone_file);
&read_env_file($timezone_file, \%tz);
$tz{'TZ'} = $_[0];
&write_env_file($timezone_file, \%tz);
&unlock_file($timezone_file);

if (-r $rtc_config) {
	# Update x86 RTC timezone too
	&lock_file($rtc_config);
	local %rtc;
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

