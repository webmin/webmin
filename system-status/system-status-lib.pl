# Functions for collecting general system info

use strict;
use warnings;
no warnings 'redefine';
BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our ($module_config_directory, %config, %gconfig, $module_name,
     $no_log_file_changes, $module_var_directory);
our $systeminfo_cron_cmd = "$module_config_directory/systeminfo.pl";
our $collected_info_file = "$module_config_directory/info";
if (!-e $collected_info_file) {
	$collected_info_file = "$module_var_directory/info";
	}
our $historic_info_dir = "$module_config_directory/history";
if (!-e $historic_info_dir) {
	$historic_info_dir = "$module_var_directory/history";
	}
our $get_collected_info_cache;

# collect_system_info()
# Returns a hash reference containing system information
sub collect_system_info
{
my $info = { };

if (&foreign_check("proc")) {
	# CPU and memory
	&foreign_require("proc");
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
	($info->{'disk_total'}, $info->{'disk_free'}, $info->{'disk_fs'}) =
		&mount::local_disk_space();
	}

# Available package updates
if (&foreign_installed("package-updates") && $config{'collect_pkgs'}) {
	&foreign_require("package-updates");
	my @poss = &package_updates::list_possible_updates(2, 1);
	$info->{'poss'} = \@poss;
	$info->{'reboot'} = &package_updates::check_reboot_required();
	}

# CPU and drive temps
if (!$config{'collect_notemp'} && defined(&proc::get_current_cpu_temps)) {
	my @cpu = &proc::get_current_cpu_temps();
	$info->{'cputemps'} = \@cpu if (@cpu);
	}
my @drive = &get_current_drive_temps();
$info->{'drivetemps'} = \@drive if (@drive);

# IO input and output
if (defined(&proc::get_cpu_io_usage)) {
	my ($user, $kernel, $idle, $io, $vm, $bin, $bout) =
		&proc::get_cpu_io_usage();
	if (defined($bin)) {
		$info->{'io'} = [ $bin, $bout ];
		}
	if (defined($user)) {
		$info->{'cpu'} = [ $user, $kernel, $idle, $io, $vm ];
		}
	}

return $info;
}

# get_collected_info()
# Returns the most recently collected system information, or the current info
sub get_collected_info
{
if ($get_collected_info_cache) {
	# Already in RAM
	return $get_collected_info_cache;
	}
my @st = stat($collected_info_file);
my $i = $config{'collect_interval'} || 'none';
if ($i ne 'none' && @st && $st[9] > time() - $i * 60 * 2) {
	my $infostr = &read_file_contents($collected_info_file);
	if ($infostr) {
		my $info = &unserialise_variable($infostr);
		if (ref($info) eq 'HASH' && keys(%$info) > 0) {
			$get_collected_info_cache = $info;
			}
		}
	}
$get_collected_info_cache ||= &collect_system_info();
return $get_collected_info_cache;
}

# save_collected_info(&info)
# Save information collected on schedule
sub save_collected_info
{
my ($info) = @_;
my $fh = "INFO";
&open_tempfile($fh, ">$collected_info_file");
&print_tempfile($fh, &serialise_variable($info));
&close_tempfile($fh);
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
	my @poss = &package_updates::list_possible_updates(1);
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
	my @ifaces;
	if ($config{'collect_ifaces'}) {
		# From module config
		@ifaces = split(/\s+/, $config{'collect_ifaces'});
		}
	else {
		# Get list from net module
		&foreign_require("net");
                if (defined(&net::active_interfaces)) {
			foreach my $i (&net::active_interfaces()) {
				my $v = defined($i->{'virtual'}) ?
						$i->{'virtual'} : '';
				if ($v eq '' &&
				    $i->{'name'} =~ /^(eth|ppp|wlan|ath|wlan)/) {
					push(@ifaces, $i->{'name'});
					}
				}
			}
		else {
			# Not available on this OS?
			@ifaces = ( "eth0" );
                        }
		}
	my $ifaces = join(" ", @ifaces);
	foreach my $iname (@ifaces) {
		&clean_language();
		my $out = &backquote_command(
			"ifconfig ".quotemeta($iname)." 2>/dev/null");
		&reset_environment();
		my $rx = $out =~ /RX\s+bytes:\s*(\d+)/i ? $1 : undef;
		my $tx = $out =~ /TX\s+bytes:\s*(\d+)/i ? $1 : undef;
		$rxtotal += $rx;
		$txtotal += $tx;
		}

	# Work out the diff since the last run, if we have it
	my %netcounts;
	my $now = time();
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
my ($ctemptotal, $ctempcount);
foreach my $t (@{$info->{'cputemps'}}) {
	$ctemptotal += $t->{'temp'};
	$ctempcount++;
	}
if ($ctemptotal) {
	push(@stats, [ "cputemp", $ctemptotal / $ctempcount ]);
	}

# Get IO blocks
if ($info->{'io'}) {
	push(@stats, [ "bin", $info->{'io'}->[0] ]);
	push(@stats, [ "bout", $info->{'io'}->[1] ]);
	}

# Get CPU user and IO time
if ($info->{'cpu'}) {
	push(@stats, [ "cpuuser", $info->{'cpu'}->[0] ]);
	push(@stats, [ "cpukernel", $info->{'cpu'}->[1] ]);
	push(@stats, [ "cpuidle", $info->{'cpu'}->[2] ]);
	push(@stats, [ "cpuio", $info->{'cpu'}->[3] ]);
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
my %all;
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
my $last;
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
# Creates or updates the Webmin function cron job, based on the interval
# set in the module config
sub setup_collectinfo_job
{
&foreign_require("webmincron");
my $step = $config{'collect_interval'};
if ($step ne 'none') {
	# Setup periodic webmin cron (removing old classic cron job)
	$step ||= 5;
	my $cron = { 'module' => $module_name,
		     'func' => 'scheduled_collect_system_info',
		     'interval' => $step * 60,
		     'args' => [],
		   };
	&webmincron::create_webmin_cron($cron, $systeminfo_cron_cmd);

	# Setup boot-time webmin cron
	my $bcron = { 'module' => $module_name,
		      'func' => 'scheduled_collect_system_info',
		      'boot' => 1,
		      'args' => ['boot'],
		   };
	&webmincron::create_webmin_cron($bcron);
	}
else {
	# Delete webmin crons (regular and boot-time)
	foreach (1..2) {
		my $cron = &webmincron::find_webmin_cron(
			$module_name, 'scheduled_collect_system_info');
		if ($cron) {
			&webmincron::delete_webmin_cron($cron);
			}
		}
	}
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
			if (($a->[0] =~ /^Temperature\s+Celsius$/i ||
			     $a->[0] =~ /^Airflow\s+Temperature\s+Cel/i) &&
			    $a->[1] > 0) {
				push(@rv, { 'device' => $d->{'device'},
					    'temp' => int($a->[1]),
					    'errors' => $st->{'errors'},
					    'failed' => !$st->{'check'} });
				last;
				}
			}
		}
	}
return @rv;
}

# scheduled_collect_system_info()
# Called by Webmin Cron to collect system info
sub scheduled_collect_system_info
{
my $start = time();

# Make sure we are not already running
if (&test_lock($collected_info_file)) {
	print STDERR "scheduled_collect_system_info : Already running\n";
	return;
	}

# Don't diff collected file
$gconfig{'logfiles'} = 0;
$gconfig{'logfullfiles'} = 0;
$WebminCore::gconfig{'logfiles'} = 0;
$WebminCore::gconfig{'logfullfiles'} = 0;
$no_log_file_changes = 1;
&lock_file($collected_info_file);

my $info = &collect_system_info();
if ($info) {
	&save_collected_info($info);
	&add_historic_collected_info($info, $start);
	}
&unlock_file($collected_info_file);
}

1;

