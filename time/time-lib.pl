#!/usr/local/bin/perl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$cron_cmd = "$module_config_directory/sync.pl";
if ($config{'zone_style'}) {
	do "$config{'zone_style'}-lib.pl";
	}

sub find_cron_job
{
&foreign_require("cron", "cron-lib.pl");
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'command'} eq $cron_cmd &&
		      $_->{'user'} eq 'root' } @jobs;
return $job;
}

# sync_time(server, hardware-too)
# Syncs the system and maybe hardware time with some server. Returns undef
# on success, or an error message on failure.
sub sync_time
{
local @servs = split(/\s+/, $_[0]);
local $servs = join(" ", map { quotemeta($_) } @servs);
local $out = &backquote_logged("ntpdate -u $servs 2>&1");
if ($? && $config{'ntp_only'}) {
	# error using ntp, but nothing else is allowed
	return &text('error_entp', "<tt>$out</tt>");
	}
elsif ($?) {
	# error using ntp. use timeservice
	local ($err, $serv);
	foreach $serv (@servs) {
		$err = undef;
		&open_socket($serv, 37, SOCK, \$err);
		read(SOCK, $rawtime, 4);
		close(SOCK);
		last if (!$err && $rawtime);
		}
	return $err if ($err);

	# Got a time .. set it
  	$rawtime = unpack("N", $rawtime);
  	$rawtime -= (17 * 366 + 53 * 365) * 24 * 60 * 60;
	local $diff = abs(time() - $rawtime);
	if ($diff > 365*24*60*60) {
		# Too big!
		return &text('error_ediff', int($diff/(24*60*60)));
		} 
  	@tm = localtime($rawtime);
	&set_system_time(@tm);
	}
else {
	$rawtime = time();
	}

if ($_[1]) {
	# Set hardware clock time to match system time (which is now correct)
	local $flags = &get_hwclock_flags();
	local $out = &backquote_logged("hwclock $flags --systohc");
	return $? ? $out : undef;
	}

return undef;
}

sub has_timezone
{
return 0 if (!defined(&list_timezones));
if (defined(&os_has_timezones)) {
	return &os_has_timezones();
	}
else {
	local @zones = &list_timezones();
	return @zones ? 1 : 0;
	}
}

# find_same_zone(file)
# Finds an identical timezone file to the one specified
sub find_same_zone
{
local @st = stat(&translate_filename($_[0]));
local $z;
foreach $z (&list_timezones()) {
	local $zf = &translate_filename("$timezones_dir/$z->[0]");
	local @zst = stat($zf);
	if ($zst[7] == $st[7]) {
		local $ex = system("diff ".&translate_filename($currentzone_link)." $zf >/dev/null 2>&1");
		if (!$ex) {
			return $z->[0];
			}
		}
	}
return undef;
}

# get_hwclock_flags()
# Returns command-line flags for hwclock
sub get_hwclock_flags
{
if ($config{'hwclock_flags'} eq "sysconfig") {
	local %clock;
	&read_env_file("/etc/sysconfig/clock", \%clock);
	return $clock{'CLOCKFLAGS'};
	}
else {
	return $config{'hwclock_flags'};
	}
}

# get_hardware_time()
# Returns the current hardware time, in localtime format. On failure returns
# an empty array, and sets the global $get_hardware_time_error
sub get_hardware_time
{
local $flags = &get_hwclock_flags();
$get_hardware_time_error = undef;
local $out = `hwclock $flags`;
if ($out =~ /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)\s+/) {
	return ($6, $5, $4, $3, &month_to_number($2), $7-1900, &weekday_to_number($1));
	}
elsif ($out =~ /^(\S+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(am|pm)\s+/i) {
	return ($7, $6, $5+($8 eq 'pm' ? 12 : 0), $2, &month_to_number($3), $4-1900, &weekday_to_number($1));
	}
else {
	$get_hardware_time_error = &text('index_ehwclock',
			"<tt>".&html_escape("hwclock $flags")."</tt>",
			"<pre>".&html_escape($out)."</pre>");
	return ( );
	}
}

# get_system_time()
# Returns the current time, in localtime format
sub get_system_time
{
return localtime(time());
}

# set_hardware_time(secs, mins, hours, day, month, year)
sub set_hardware_time
{
local ($second, $minute, $hour, $date, $month, $year) = @_;
$month++;
$year += 1900;
local $format = "--set --date=".
		quotemeta("$month/$date/$year $hour:$minute:$second");
local $flags = &get_hwclock_flags();
local $out = &backquote_logged("hwclock $flags $format 2>&1");
return $? ? $out : undef;
}

# set_system_time(secs, mins, hours, day, month, year)
sub set_system_time
{
local ($second, $minute, $hour, $date, $month, $year) = @_;
$second = &zeropad($second, 2);
$minute = &zeropad($minute, 2);
$hour = &zeropad($hour, 2);
$date = &zeropad($date, 2);
$month = &zeropad($month+1, 2);
$year = &zeropad($year+1900, 4);
local $format;
if ($config{'seconds'} == 2) {
	$format = $year.$month.$date.$hour.$minute.".".$second;
	}
elsif ($config{'seconds'} == 1) {
	$format = $month.$date.$hour.$minute.$year.".".$second;
	}
else {
	$format = $month.$date.$hour.$minute.substr($year, -2);
	}
local $out = &backquote_logged("echo yes | date ".quotemeta($format)." 2>&1");
if ($gconfig{'os_type'} eq 'freebsd' || $gconfig{'os_type'} eq 'netbsd') {
	return int($?/256) == 1 ? $out : undef;
	}
else {
	return $? ? $out : undef;
	}
}

sub zeropad
{
local ($str, $len) = @_;
while(length($str) < $len) {
	$str = "0".$str;
	}
return $str;
}

@weekday_names = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );

# weekday_to_number(day)
# Converts a day like Mon to a number like 1
sub weekday_to_number
{
for($i=0; $i<@weekday_names; $i++) {
	return $i if (lc(substr($weekday_names[$i], 0, 3)) eq lc($_[0]));
	}
return undef;
}

sub number_to_weekday
{
return ucfirst($weekday_names[$_[0]]);
}

# Returns 1 if this system supports setting the hardware clock.
sub support_hwtime
{
if ($config{'hwtime'} == 1) {
	return 1;
	}
elsif ($config{'hwtime'} == 0) {
	return 0;
	}
else {
	return &has_command("hwclock") &&
	       !&running_in_xen() && !&running_in_vserver() &&
	       !&running_in_openvz() && !&running_in_zone();
	}
}

1;

