# Functions for collecting general system info
#
# XXX Webmin module page to enable background collection
# XXX Use on main page of blue theme
# XXX Show package updates on blue theme main page
# XXX Collect from Cloudmin
# XXX Cloudmin should enable background collection

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();

# collect_system_info()
# Returns a hash reference containing system information
sub collect_system_info
{
local $info = { };

# System information
if (&foreign_check("proc")) {
	&foreign_require("proc", "proc-lib.pl");
	if (defined(&proc::get_cpu_info)) {
		local @c = &proc::get_cpu_info();
		$info->{'load'} = \@c;
		}
	local @procs = &proc::list_processes();
	$info->{'procs'} = scalar(@procs);
	if ($config{'mem_cmd'}) {
		# Get from custom command
		local $out = &backquote_command($config{'mem_cmd'});
		local @lines = split(/\r?\n/, $out);
		$info->{'mem'} = [ map { $_/1024 } @lines ];
		}
	elsif (defined(&proc::get_memory_info)) {
		local @m = &proc::get_memory_info();
		$info->{'mem'} = \@m;
		if ($m[0] > 128*1024*1024 && $gconfig{'os_type'} eq 'freebsd') {
			# Some Webmin versions overstated memory by a factor
			# of 1k on FreeBSD - fix it
			$m[0] /= 1024;
			$m[1] /= 1024;
			}
		}
	if (&foreign_check("mount")) {
		&require_useradmin();
		&foreign_require("mount", "mount-lib.pl");
		local @mounted = &mount::list_mounted();
		local $total = 0;
		local $free = 0;
		local $donezone;
		foreach my $m (@mounted) {
			if ($m->[2] =~ /^ext/ ||
			    $m->[2] eq "reiserfs" || $m->[2] eq "ufs" ||
			    $m->[2] eq "zfs" || $m->[2] eq "simfs" ||
			    $m->[2] eq "xfs" || $m->[2] eq "jfs" ||
			    $m->[1] =~ /^\/dev\// || $m->[1] eq $home_base) {
				if ($m->[1] =~ /^(zones|zonas)\/([^\/]+)/ &&
				    $m->[2] eq "zfs" &&
				    $donezone{$2}++) {
					# Only count each zone once, as there
					# may be mounts from zones/foo/bar
					# and zones/foo/smeg that really refer
					# to the zone source.
					next;
					}
				local ($t, $f) =
					&mount::disk_space($m->[2], $m->[0]);
				$total += $t*1024;
				$free += $f*1024;
				}
			}
		$info->{'disk_total'} = $total;
		$info->{'disk_free'} = $free;
		}
	}

# CPU and kernel
local $out = &backquote_command(
	"uname -r 2>/dev/null ; uname -m 2>/dev/null ; uname -s 2>/dev/null");
local ($r, $m, $o) = split(/\r?\n/, $out);
$info->{'kernel'} = { 'version' => $r,
		      'arch' => $m,
		      'os' => $o };

# Available package updates
if (&foreign_check("package-updates")) {
	&foreign_require("package-updates"):
	local @poss = &package_updates::list_possible_updates(2);
	$info->{'poss'} = \@poss;
	}

# CPU and drive temps
local @cpu = &get_current_cpu_temps();
$info->{'cputemps'} = \@cpu if (@cpu);
local @drive = &get_current_drive_temps();
$info->{'drivetemps'} = \@drive if (@drive);

return $info;
}

# get_collected_info()
# Returns the most recently collected system information, or the current info
sub get_collected_info
{
local $infostr = $config{'collect_interval'} eq 'none' ? undef :
			&read_file_contents($collected_info_file);
if ($infostr) {
	local $info = &unserialise_variable($infostr);
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
local ($info) = @_;
&open_tempfile(INFO, ">$collected_info_file");
&print_tempfile(INFO, &serialise_variable($info));
&close_tempfile(INFO);
}

# refresh_startstop_status()
# Refresh regularly collected info on status of services
sub refresh_startstop_status
{
local $info = &get_collected_info();
$info->{'startstop'} = [ &get_startstop_links() ];
&save_collected_info($info);
}

# refresh_possible_packages(&newpackages)
# Refresh regularly collected info on available packages
sub refresh_possible_packages
{
local ($pkgs) = @_;
local %pkgs = map { $_, 1 } @$pkgs;
local $info = &get_collected_info();
if ($info->{'poss'} && &foreign_check("security-updates")) {
	&foreign_require("security-updates", "security-updates-lib.pl");
	local @poss = &security_updates::list_possible_updates(2);
	$info->{'poss'} = \@poss;
	}
&save_collected_info($info);
}

# add_historic_collected_info(&info, time)
# Add to the collected info log files the current CPU load, memory uses, swap
# use, disk use and other info we might want to graph
sub add_historic_collected_info
{
local ($info, $time) = @_;
if (!-d $historic_info_dir) {
	&make_dir($historic_info_dir, 0700);
	}
local @stats;
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
push(@stats, [ "doms", $info->{'fcount'}->{'doms'} ]);
push(@stats, [ "users", $info->{'fcount'}->{'users'} ]);
push(@stats, [ "aliases", $info->{'fcount'}->{'aliases'} ]);
local $qlimit = 0;
local $qused = 0;
foreach my $q (@{$info->{'quota'}}) {
	$qlimit += $q->[2];
	$qused += $q->[1]+$q->[3];
	}
push(@stats, [ "quotalimit", $qlimit ]);
push(@stats, [ "quotaused", $qused ]);

# Get mail since the last collection time
local $now = time();
if (-r $procmail_log_file) {
	# Get last seek position
	local $lastinfo = &read_file_contents("$historic_info_dir/procmailpos");
	local @st = stat($procmail_log_file);
	local ($lastpos, $lastinode, $lasttime);
	if (defined($lastinfo)) {
		($lastpos, $lastinode, $lasttime) = split(/\s+/, $lastinfo);
		}
	else {
		# For the first run, start at the end of the file
		$lastpos = $st[7];
		$lastinode = $st[1];
		$lasttime = time();
		}

	open(PROCMAILLOG, $procmail_log_file);
	if ($st[1] == $lastinode && $lastpos) {
		seek(PROCMAILLOG, $lastpos, 0);
		}
	else {
		$lastpos = 0;
		}
	local ($mailcount, $spamcount, $viruscount) = (0, 0, 0);
	while(<PROCMAILLOG>) {
		$lastpos += length($_);
		s/\r|\n//g;
		local %log = map { split(/:/, $_, 2) } split(/\s+/, $_);
		if ($log{'User'}) {
			$mailcount++;
			if ($log{'Mode'} eq 'Spam') {
				$spamcount++;
				}
			elsif ($log{'Mode'} eq 'Virus') {
				$viruscount++;
				}
			}
		}
	close(PROCMAILLOG);
	local $mins = ($now - $lasttime) / 60.0;
	push(@stats, [ "mailcount", $mins ? $mailcount / $mins : 0 ]);
	push(@stats, [ "spamcount", $mins ? $spamcount / $mins : 0 ]);
	push(@stats, [ "viruscount", $mins ? $viruscount / $mins : 0 ]);

	# Save last seek
	&open_tempfile(PROCMAILPOS, ">$historic_info_dir/procmailpos");
	&print_tempfile(PROCMAILPOS, $lastpos," ",$st[1]," ",$now."\n");
	&close_tempfile(PROCMAILPOS);
	}

# Get network traffic counts since last run
if (&foreign_check("net") && $gconfig{'os_type'} =~ /-linux$/) {
	# Get the current byte count
	local $rxtotal = 0;
	local $txtotal = 0;
	if ($config{'collect_ifaces'}) {
		# From module config
		@ifaces = split(/\s+/, $config{'collect_ifaces'});
		}
	else {
		# Get list from net module
		&foreign_require("net", "net-lib.pl");
		foreach my $i (&net::active_interfaces()) {
			if ($i->{'virtual'} eq '' &&
			    $i->{'name'} =~ /^(eth|ppp|wlan|ath|wlan)/) {
				push(@ifaces, $i->{'name'});
				}
			}
		}
	local $ifaces = join(" ", @ifaces);
	foreach my $iname (@ifaces) {
		local $out = &backquote_command(
			"LC_ALL='' LANG='' ifconfig ".
			quotemeta($iname)." 2>/dev/null");
		local $rx = $out =~ /RX\s+bytes:\s*(\d+)/i ? $1 : undef;
		local $tx = $out =~ /TX\s+bytes:\s*(\d+)/i ? $1 : undef;
		$rxtotal += $rx;
		$txtotal += $tx;
		}

	# Work out the diff since the last run, if we have it
	local %netcounts;
	if (&read_file("$historic_info_dir/netcounts", \%netcounts) &&
	    $netcounts{'rx'} && $netcounts{'tx'} &&
	    $netcounts{'ifaces'} eq $ifaces &&
	    $rxtotal >= $netcounts{'rx'} && $txtotal >= $netcounts{'tx'}) {
		local $secs = ($now - $netcounts{'now'}) * 1.0;
		local $rxscaled = ($rxtotal - $netcounts{'rx'}) / $secs;
		local $txscaled = ($txtotal - $netcounts{'tx'}) / $secs;
		if ($rxscaled >= $netcounts{'rx_max'}) {
			$netcounts{'rx_max'} = $rxscaled;
			}
		if ($txscaled >= $netcounts{'tx_max'}) {
			$netcounts{'tx_max'} = $txscaled;
			}
		push(@stats, [ "rx", $rxscaled, $netcounts{'rx_max'} ]);
		push(@stats, [ "tx", $txscaled, $netcounts{'tx_max'} ]);
		}

	# Save the last counts
	$netcounts{'rx'} = $rxtotal;
	$netcounts{'tx'} = $txtotal;
	$netcounts{'now'} = $now;
	$netcounts{'ifaces'} = $ifaces;
	&write_file("$historic_info_dir/netcounts", \%netcounts);
	}

# Get drive temperatures
local ($temptotal, $tempcount);
foreach my $t (@{$info->{'drivetemps'}}) {
	$temptotal += $t->{'temp'};
	$tempcount++;
	}
if ($temptotal) {
	push(@stats, [ "drivetemp", $temptotal / $tempcount ]);
	}

# Get CPU temperature
local ($temptotal, $tempcount);
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
local %maxpossible;
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
local ($stat, $start, $end) = @_;
local @rv;
local $last_time;
local $now = time();
open(HISTORY, "$historic_info_dir/$stat");
while(<HISTORY>) {
	chop;
	local ($time, $value) = split(" ", $_);
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
local ($start, $end) = @_;
foreach my $f (&list_historic_stats()) {
	local @rv = &list_historic_collected_info($f, $start, $end);
	$all{$f} = \@rv;
	}
closedir(HISTDIR);
return \%all;
}

# get_historic_maxes()
# Returns a hash reference from stats to the max possible values ever seen
sub get_historic_maxes
{
local %maxpossible;
&read_file("$historic_info_dir/maxes", \%maxpossible);
return \%maxpossible;
}

# get_historic_first_last(stat)
# Returns the Unix time for the first and last stats recorded
sub get_historic_first_last
{
local ($stat) = @_;
open(HISTORY, "$historic_info_dir/$stat") || return (undef, undef);
local $first = <HISTORY>;
$first || return (undef, undef);
chop($first);
local ($firsttime, $firstvalue) = split(" ", $first);
seek(HISTORY, 2, -256) || seek(HISTORY, 0, 0);
while(<HISTORY>) {
	$last = $_;
	}
close(HISTORY);
chop($last);
local ($lasttime, $lastvalue) = split(" ", $last);
return ($firsttime, $lasttime);
}

# list_historic_stats()
# Returns a list of variables on which we have stats
sub list_historic_stats
{
local @rv;
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
# Creates or updates the collectinfo.pl cron job, based on the schedule
# set in the module config.
sub setup_collectinfo_job
{
# Work out correct steps
local $step = $config{'collect_interval'};
$step = 5 if (!$step || $step eq 'none');
local $offset = int(rand()*$step);
local @mins;
for(my $i=$offset; $i<60; $i+= $step) {
	push(@mins, $i);
	}
local $job = &find_virtualmin_cron_job($collect_cron_cmd);
if (!$job && $config{'collect_interval'} ne 'none') {
	# Create, and run for the first time
	$job = { 'mins' => join(',', @mins),
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		 'user' => 'root',
		 'active' => 1,
		 'command' => $collect_cron_cmd };
	&cron::create_cron_job($job);
	}
elsif ($job && $config{'collect_interval'} ne 'none') {
	# Update existing job, if step has changed
	local @oldmins = split(/,/, $job->{'mins'});
	local $oldstep = $oldmins[0] eq '*' ? 1 :
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
&cron::create_wrapper($collect_cron_cmd, $module_name, "collectinfo.pl");
}

# get_current_drive_temps()
# Returns a list of hashes, containing device and temp keys
sub get_current_drive_temps
{
local @rv;
if (!$config{'collect_notemp'} && $virtualmin_pro &&
    &foreign_installed("smart-status")) {
	&foreign_require("smart-status");
	foreach my $d (&smart_status::list_smart_disks_partitions()) {
		local $st = &smart_status::get_drive_status($d->{'device'}, $d);
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
local @rv;
if (!$config{'collect_notemp'} && $virtualmin_pro &&
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

