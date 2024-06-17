#!/usr/local/bin/perl

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();
our ($module_config_directory, $module_name, %text, %config, %gconfig);
our ($timezones_file, $currentzone_link, $currentzone_file, $timezones_dir,
     $sysclock_file);
our ($get_hardware_time_error);
our $cron_cmd = "$module_config_directory/sync.pl";
our $cronyd_name = $gconfig{'os_type'} eq 'debian-linux' ? 'chrony' : 'chronyd';
our $rawtime;
if ($config{'zone_style'}) {
	do "$config{'zone_style'}-lib.pl";
	}
&foreign_require("webmincron");

sub find_cron_job
{
&foreign_require("cron", "cron-lib.pl");
my @jobs = &cron::list_cron_jobs();
my ($job) = grep { $_->{'command'} && $_->{'user'} &&
		   $_->{'command'} eq $cron_cmd &&
		   $_->{'user'} eq 'root' } @jobs;
return $job;
}

sub find_webmin_cron_job
{
return &webmincron::find_webmin_cron($module_name, 'sync_time_cron');
}

# sync_time(server, hardware-too)
# Syncs the system and maybe hardware time with some server. Returns undef
# on success, or an error message on failure.
sub sync_time
{
my ($server, $hwtoo) = @_;
my @servs = split(/\s+/, $server);
my $servs = join(" ", map { quotemeta($_) } @servs);
my $out;
if (&has_command("ntpdate")) {
	$out = &backquote_logged("ntpdate -u $servs 2>&1");
	}
elsif (&has_command("sntp")) {
	$out = &backquote_logged("sntp -s $servs 2>&1");
	}
elsif (&foreign_require('init') && &init::action_status($cronyd_name) > 0 && &has_command("chronyc")) {
	my $chronyd_running = &init::status_action($cronyd_name);
	$out = &backquote_logged("systemctl restart $cronyd_name 2>&1");
	$out .= &backquote_logged("chronyc makestep 2>&1");
	sleep ($chronyd_running ? 5 : 15);
	if (!$chronyd_running) {
		&backquote_logged("systemctl stop $cronyd_name 2>&1");
		}
	}
elsif (&foreign_require('init') && &init::action_status('systemd-timesyncd') > 0) {
	my $systemd_timesyncd_running = &init::status_action('systemd-timesyncd');
	$out = &backquote_logged("systemctl restart systemd-timesyncd 2>&1");
	sleep ($systemd_timesyncd_running ? 5 : 15);
	if (!$systemd_timesyncd_running) {
		&backquote_logged("systemctl stop systemd-timesyncd 2>&1");
		}
	}
else {
	$out = "Missing ntpdate and sntp commands";
	$? = 1;
	}
if ($? && $config{'ntp_only'}) {
	# error using ntp, but nothing else is allowed
	return &text('error_entp', "$out");
	}
elsif ($?) {
	# error using ntp. use timeservice
	my ($err, $serv);
	foreach $serv (@servs) {
		$err = undef;
		my $fh = "SOCK";
		&open_socket($serv, 37, $fh, \$err);
		read($fh, $rawtime, 4);
		close($fh);
		last if (!$err && $rawtime);
		}
	return $err if ($err);

	# Got a time .. set it
  	$rawtime = unpack("N", $rawtime);
  	$rawtime -= (17 * 366 + 53 * 365) * 24 * 60 * 60;
	my $diff = abs(time() - $rawtime);
	if ($diff > 365*24*60*60) {
		# Too big!
		return &text('error_ediff', int($diff/(24*60*60)));
		} 
  	my @tm = localtime($rawtime);
	&set_system_time(@tm);
	}

if ($hwtoo) {
	# Set hardware clock time to match system time (which is now correct)
	my $flags = &get_hwclock_flags();
	my $out = &backquote_logged("hwclock $flags --systohc");
	return $? ? $out : undef;
	}

return undef;
}

# sync_time_cron()
# Called from webmin cron to sync from the configured server
sub sync_time_cron
{
my $err = &sync_time($config{'timeserver'}, $config{'timeserver_hardware'});
print STDERR $err if ($err);
}

sub has_timezone
{
return 0 if (!defined(&list_timezones));
if (defined(&os_has_timezones)) {
	return &os_has_timezones();
	}
else {
	my @zones = &list_timezones();
	return @zones ? 1 : 0;
	}
}

# find_same_zone(file)
# Finds an identical timezone file to the one specified
sub find_same_zone
{
my @st = stat(&translate_filename($_[0]));
my $z;
foreach $z (&list_timezones()) {
	my $zf = &translate_filename("$timezones_dir/$z->[0]");
	my @zst = stat($zf);
	if ($zst[7] == $st[7]) {
		my $ex = system("diff ".&translate_filename($currentzone_link)." $zf >/dev/null 2>&1");
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
if ($config{'hwclock_flags'} && $config{'hwclock_flags'} eq "sysconfig") {
	my %clock;
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
my $flags = &get_hwclock_flags();
$flags ||= "";
$get_hardware_time_error = undef;
&clean_language();
my $out = &backquote_command("hwclock $flags 2>/dev/null");
&reset_environment();
if ($out =~ /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)\s+/) {
	return ($6, $5, $4, $3, &month_to_number($2), $7-1900, &weekday_to_number($1));
	}
elsif ($out =~ /^(\S+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(am|pm)\s+/i) {
	return ($7, $6, $5+($8 eq 'pm' ? 12 : 0), $2, &month_to_number($3), $4-1900, &weekday_to_number($1));
	}
elsif ($out =~ /^(\d+)\-(\d+)\-(\d+)\s+(\d+):(\d+):(\d+)/) {
	# Format like 2016-06-10 22:58:17.999536+3:00
	return ($6, $5, $4, $3, $2-1, $1-1900);
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
my ($second, $minute, $hour, $date, $month, $year) = @_;
$month++;
$year += 1900;
my $format = "--set --date=".
		quotemeta("$year-$month-$date $hour:$minute:$second");
my $flags = &get_hwclock_flags();
my $out = &backquote_logged("hwclock $flags $format 2>&1");
return $? ? $out : undef;
}

# set_system_time(secs, mins, hours, day, month, year)
sub set_system_time
{
my ($second, $minute, $hour, $date, $month, $year) = @_;
$second = &zeropad($second, 2);
$minute = &zeropad($minute, 2);
$hour = &zeropad($hour, 2);
$date = &zeropad($date, 2);
$month = &zeropad($month+1, 2);
$year = &zeropad($year+1900, 4);
if (&has_command('timedatectl')) {
	my ($out, $err);
	 &execute_command("timedatectl set-time ".
		quotemeta("$year-$month-$date $hour:$minute:$second"), undef, \$out, \$err);
	return $out || $err ? ($out || $err) : undef;
	}
else {
	my $format;
	if ($config{'seconds'} == 2) {
		$format = $year.$month.$date.$hour.$minute.".".$second;
		}
	elsif ($config{'seconds'} == 1) {
		$format = $month.$date.$hour.$minute.$year.".".$second;
		}
	else {
		$format = $month.$date.$hour.$minute.substr($year, -2);
		}
	my $out = &backquote_logged("echo yes | date ".quotemeta($format)." 2>&1");
	if ($gconfig{'os_type'} eq 'freebsd' || $gconfig{'os_type'} eq 'netbsd') {
		return int($?/256) == 1 ? $out : undef;
		}
	else {
		return $? ? $out : undef;
		}
	}
}

sub zeropad
{
my ($str, $len) = @_;
while(length($str) < $len) {
	$str = "0".$str;
	}
return $str;
}

our @weekday_names = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );

# weekday_to_number(day)
# Converts a day like Mon to a number like 1
sub weekday_to_number
{
for(my $i=0; $i<@weekday_names; $i++) {
	return $i if (lc(substr($weekday_names[$i], 0, 3)) eq lc($_[0]));
	}
return undef;
}

sub number_to_weekday
{
return defined($_[0]) ? ucfirst($weekday_names[$_[0]]) : undef;
}

# Returns 1 if this system supports setting the hardware clock.
sub support_hwtime
{
return &has_command("hwclock") &&
       &execute_command("hwclock") == 0 &&
       !&running_in_xen() && !&running_in_vserver() &&
       !&running_in_openvz() && !&running_in_zone();
}

# config_pre_load(mod-info-ref, [mod-order-ref])
# Check if some config options are conditional,
# and if not allowed, remove them from listing
sub config_pre_load
{
my ($modconf_info, $modconf_order) = @_;
my @forbidden_keys;

# Do not display timeformat for Linux systems
push(@forbidden_keys, 'seconds')
	if ($gconfig{'os_type'} =~ /linux$/);

# Remove forbidden from display
if ($modconf_info) {
	foreach my $fkey (@forbidden_keys) {
		delete($modconf_info->{$fkey});
		@{$modconf_order} = grep { $_ ne $fkey } @{$modconf_order}
			if ($modconf_order);
		}
	}
}

1;

