# Functions for collecting general system info
#
# XXX Collect from Cloudmin
# XXX Cloudmin should enable background collection

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
$systeminfo_cron_cmd = "$module_config_directory/systeminfo.pl";
$collected_info_file = "$module_config_directory/info";
$historic_info_dir = "$module_config_directory/history";

# collect_system_info()
# Returns a hash reference containing system information
sub collect_system_info
{
my $info = { };

if (&foreign_check("proc")) {
	# CPU and memory
	&foreign_require("proc", "proc-lib.pl");
	if (defined(&proc::get_cpu_info)) {
		my @c = &proc::get_cpu_info();
		$info->{'load'} = \@c;
		}
	my @procs = &proc::list_processes();
	$info->{'procs'} = scalar(@procs);
	if (defined(&proc::get_memory_info)) {
		my @m = &proc::get_memory_info();
		$info->{'mem'} = \@m;
		if ($m[0] > 128*1024*1024 && $gconfig{'os_type'} eq 'freebsd') {
			# Some Webmin versions overstated memory by a factor
			# of 1k on FreeBSD - fix it
			$m[0] /= 1024;
			$m[1] /= 1024;
			}
		}

	# CPU and kernel
	my ($r, $m, $o) = &proc::get_kernel_info();
	$info->{'kernel'} = { 'version' => $r,
			      'arch' => $m,
			      'os' => $o };
	}

# Disk space on local filesystems
if (&foreign_check("mount")) {
	&foreign_require("mount");
	($info->{'disk_total'}, $info->{'disk_free'}) =
		&mount::local_disk_space();
	}

# Available package updates
if (&foreign_installed("package-updates") && $config{'collect_pkgs'}) {
	&foreign_require("package-updates");
	my @poss = &package_updates::list_possible_updates(2, 1);
	$info->{'poss'} = \@poss;
	}

# CPU and drive temps
my @cpu = &get_current_cpu_temps();
$info->{'cputemps'} = \@cpu if (@cpu);
my @drive = &get_current_drive_temps();
$info->{'drivetemps'} = \@drive if (@drive);

return $info;
}

# get_collected_info()
# Returns the most recently collected system information, or the current info
sub get_collected_info
{
my $infostr = $config{'collect_interval'} eq 'none' ? undef :
			&read_file_contents($collected_info_file);
if ($infostr) {
	my $info = &unserialise_variable($infostr);
	if (ref($info) eq 'HASH' && keys(%$info) > 0) {
		return $info;
		}
	}
return &collect_system_info();
}

# save_collected_info(&info)
# Save information collected on schedule
sub save_collected_info
{
my ($info) = @_;
&open_tempfile(INFO, ">$collected_info_file");
&print_tempfile(INFO, &serialise_variable($info));
&close_tempfile(INFO);
}

# refresh_possible_packages(&newpackages)
# Refresh regularly collected info on available packages
sub refresh_possible_packages
{
my ($pkgs) = @_;
my %pkgs = map { $_, 1 } @$pkgs;
my $info = &get_collected_info();
if ($info->{'poss'} && &foreign_installed("package-updates")) {
	&foreign_require("package-updates");
	my @poss = &package_updates::list_possible_updates(2);
	$info->{'poss'} = \@poss;
	}
&save_collected_info($info);
}

# add_historic_collected_info(&info, time)
# Add to the collected info log files the current CPU load, memory uses, swap
# use, disk use and other info we might want to graph
sub add_historic_collected_info
{
my ($info, $time) = @_;
if (!-d $historic_info_dir) {
	&make_dir($historic_info_dir, 0700);
	}
my @stats;
push(@stats, [ "load", $info->{'load'}->[0] ]) if ($info->{'load'});
push(@stats, [ "load5", $info->{'load'}->[1] ]) if ($info->{'load'});
push(@stats, [ "load15", $info->{'load'}->[2] ]) if ($info->{'load'});
push(@stats, [ "procs", $info->{'procs'} ]) if ($info->{'procs'});
if ($info->{'mem'}) {
	push(@stats, [ "memused",
		       ($info->{'mem'}->[0]-$info->{'mem'}->[1])*1024,
		       $info->{'mem'}->[0]*1024 ]);
	if ($info->{'mem'}->[2]) {
		push(@stats, [ "swapused",
			      ($info->{'mem'}->[2]-$info->{'mem'}->[3])*1024,
			      $info->{'mem'}->[2]*1024 ]);
		}
	}
if ($info->{'disk_total'}) {
	push(@stats, [ "diskused",
		       $info->{'disk_total'}-$info->{'disk_free'},
		       $info->{'disk_total'} ]);
	}

# Get network traffic counts since last run
if (&foreign_check("net") && $gconfig{'os_type'} =~ /-linux$/) {
	# Get the current byte count
	my $rxtotal = 0;
	my $txtotal = 0;
	if ($config{'collect_ifaces'}) {
		# From module config
		@ifaces = split(/\s+/, $config{'collect_ifaces'});
		}
	else {
		# Get list from net module
		&foreign_require("net");
		foreach my $i (&net::active_interfaces()) {
			if ($i->{'virtual'} eq '' &&
			    $i->{'name'} =~ /^(eth|ppp|wlan|ath|wlan)/) {
				push(@ifaces, $i->{'name'});
				}
			}
		}
	my $ifaces = join(" ", @ifaces);
	foreach my $iname (@ifaces) {
		my $out = &backquote_command(
			"LC_ALL='' LANG='' ifconfig ".
			quotemeta($iname)." 2>/dev/null");
		my $rx = $out =~ /RX\s+bytes:\s*(\d+)/i ? $1 : undef;
		my $tx = $out =~ /TX\s+bytes:\s*(\d+)/i ? $1 : undef;
		$rxtotal += $rx;
		$txtotal += $tx;
		}

	# Work out the diff since the last run, if we have it
	my %netcounts;
	if (&read_file("$historic_info_dir/netcounts", \%netcounts) &&
	    $netcounts{'rx'} && $netcounts{'tx'} &&
	    $netcounts{'ifaces'} eq $ifaces &&
	    $rxtotal >= $netcounts{'rx'} && $txtotal >= $netcounts{'tx'}) {
		my $secs = ($now - $netcounts{'now'}) * 1.0;
		if ($secs) {
			my $rxscaled = ($rxtotal - $netcounts{'rx'}) / $secs;
			my $txscaled = ($txtotal - $netcounts{'tx'}) / $secs;
			if ($rxscaled >= $netcounts{'rx_max'}) {
				$netcounts{'rx_max'} = $rxscaled;
				}
			if ($txscaled >= $netcounts{'tx_max'}) {
				$netcounts{'tx_max'} = $txscaled;
				}
			push(@stats, [ "rx",$rxscaled, $netcounts{'rx_max'} ]);
			push(@stats, [ "tx",$txscaled, $netcounts{'tx_max'} ]);
			}
		}

	# Save the last counts
	$netcounts{'rx'} = $rxtotal;
	$netcounts{'tx'} = $txtotal;
	$netcounts{'now'} = $now;
	$netcounts{'ifaces'} = $ifaces;
	&write_file("$historic_info_dir/netcounts", \%netcounts);
	}

# Get drive temperatures
my ($temptotal, $tempcount);
foreach my $t (@{$info->{'drivetemps'}}) {
	$temptotal += $t->{'temp'};
	$tempcount++;
	}
if ($temptotal) {
	push(@stats, [ "drivetemp", $temptotal / $tempcount ]);
	}

# Get CPU temperature
my ($temptotal, $tempcount);
foreach my $t (@{$info->{'cputemps'}}) {
	$temptotal += $t->{'temp'};
	$tempcount++;
	}
if ($temptotal) {
	push(@stats, [ "cputemp", $temptotal / $tempcount ]);
	}

# Write to the file
foreach my $stat (@stats) {
	open(HISTORY, ">>$historic_info_dir/$stat->[0]");
	print HISTORY $time," ",$stat->[1],"\n";
	close(HISTORY);
	}

# Update the file storing the max possible value for each variable
my %maxpossible;
&read_file("$historic_info_dir/maxes", \%maxpossible);
foreach my $stat (@stats) {
	if ($stat->[2] && $stat->[2] > $maxpossible{$stat->[0]}) {
		$maxpossible{$stat->[0]} = $stat->[2];
		}
	}
&write_file("$historic_info_dir/maxes", \%maxpossible);
}

# list_historic_collected_info(stat, [start], [end])
# Returns an array of times and values for some stat, within the given
# time period
sub list_historic_collected_info
{
my ($stat, $start, $end) = @_;
my @rv;
my $last_time;
my $now = time();
open(HISTORY, "$historic_info_dir/$stat");
while(<HISTORY>) {
	chop;
	my ($time, $value) = split(" ", $_);
	next if ($time < $last_time ||	# No time travel or future data
		 $time > $now);
	if ((!defined($start) || $time >= $start) &&
	    (!defined($end) || $time <= $end)) {
		push(@rv, [ $time, $value ]);
		}
	if (defined($end) && $time > $end) {
		last;	# Past the end point
		}
	$last_time = $time;
	}
close(HISTORY);
return @rv;
}

# list_all_historic_collected_info([start], [end])
# Returns a hash mapping stats to data within some time period
sub list_all_historic_collected_info
{
my ($start, $end) = @_;
foreach my $f (&list_historic_stats()) {
	my @rv = &list_historic_collected_info($f, $start, $end);
	$all{$f} = \@rv;
	}
closedir(HISTDIR);
return \%all;
}

# get_historic_maxes()
# Returns a hash reference from stats to the max possible values ever seen
sub get_historic_maxes
{
my %maxpossible;
&read_file("$historic_info_dir/maxes", \%maxpossible);
return \%maxpossible;
}

# get_historic_first_last(stat)
# Returns the Unix time for the first and last stats recorded
sub get_historic_first_last
{
my ($stat) = @_;
open(HISTORY, "$historic_info_dir/$stat") || return (undef, undef);
my $first = <HISTORY>;
$first || return (undef, undef);
chop($first);
my ($firsttime, $firstvalue) = split(" ", $first);
seek(HISTORY, 2, -256) || seek(HISTORY, 0, 0);
while(<HISTORY>) {
	$last = $_;
	}
close(HISTORY);
chop($last);
my ($lasttime, $lastvalue) = split(" ", $last);
return ($firsttime, $lasttime);
}

# list_historic_stats()
# Returns a list of variables on which we have stats
sub list_historic_stats
{
my @rv;
opendir(HISTDIR, $historic_info_dir);
foreach my $f (readdir(HISTDIR)) {
	if ($f =~ /^[a-z]+[0-9]*$/ && $f ne "maxes" && $f ne "procmailpos" &&
	    $f ne "netcounts") {
		push(@rv, $f);
		}
	}
closedir(HISTDIR);
return @rv;
}

# setup_collectinfo_job()
# Creates or updates the systeminfo.pl cron job, based on the schedule
# set in the module config.
sub setup_collectinfo_job
{
&foreign_require("cron");

# Work out correct steps
my $step = $config{'collect_interval'};
$step = 5 if (!$step || $step eq 'none');
my $offset = int(rand()*$step);
my @mins;
for(my $i=$offset; $i<60; $i+= $step) {
	push(@mins, $i);
	}
my $job = &cron::find_cron_job($systeminfo_cron_cmd);

if (!$job && $config{'collect_interval'} ne 'none') {
	# Create, and run for the first time
	$job = { 'mins' => join(',', @mins),
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		 'user' => 'root',
		 'active' => 1,
		 'command' => $systeminfo_cron_cmd };
	&cron::create_cron_job($job);
	}
elsif ($job && $config{'collect_interval'} ne 'none') {
	# Update existing job, if step has changed
	my @oldmins = split(/,/, $job->{'mins'});
	my $oldstep = $oldmins[0] eq '*' ? 1 :
			 @oldmins == 1 ? 60 :
			 $oldmins[1]-$oldmins[0];
	if ($step != $oldstep) {
		$job->{'mins'} = join(',', @mins);
		&cron::change_cron_job($job);
		}
	}
elsif ($job && $config{'collect_interval'} eq 'none') {
	# No longer wanted, so delete
	&cron::delete_cron_job($job);
	}
&cron::create_wrapper($systeminfo_cron_cmd, $module_name, "systeminfo.pl");
}

# get_current_drive_temps()
# Returns a list of hashes, containing device and temp keys
sub get_current_drive_temps
{
my @rv;
if (!$config{'collect_notemp'} &&
    &foreign_installed("smart-status")) {
	&foreign_require("smart-status");
	foreach my $d (&smart_status::list_smart_disks_partitions()) {
		my $st = &smart_status::get_drive_status($d->{'device'}, $d);
		foreach my $a (@{$st->{'attribs'}}) {
			if ($a->[0] =~ /^Temperature\s+Celsius$/i &&
			    $a->[1] > 0) {
				push(@rv, { 'device' => $d->{'device'},
					    'temp' => int($a->[1]) });
				}
			}
		}
	}
return @rv;
}

# get_current_cpu_temps()
# Returns a list of hashes containing core and temp keys
sub get_current_cpu_temps
{
my @rv;
if (!$config{'collect_notemp'} &&
    $gconfig{'os_type'} =~ /-linux$/ && &has_command("sensors")) {
	&open_execute_command(SENSORS, "sensors </dev/null 2>/dev/null", 1);
	while(<SENSORS>) {
		if (/Core\s+(\d+):\s+([\+\-][0-9\.]+)/) {
			push(@rv, { 'core' => $1,
				    'temp' => $2 });
			}
		elsif (/CPU:\s+([\+\-][0-9\.]+)/) {
			push(@rv, { 'core' => 0,
				    'temp' => $1 });
			}
		}
	close(SENSORS);
	}
return @rv;
}

1;

